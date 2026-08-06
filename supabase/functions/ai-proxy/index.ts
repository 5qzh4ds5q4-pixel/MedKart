// MedKart ai-proxy Edge Function
//
// İstemci (Flutter/web) artık Gemini/DeepSeek/GLM'i DİREKT çağırmıyor — bu
// fonksiyona istek atıyor, o da ilgili sağlayıcıya gidip HAM cevabı aynen
// geri dönüyor. Prompt kurma/response parse etme mantığı istemcide
// (GeminiService/DeepSeekService/GlmService) DEĞİŞMEDİ; bu fonksiyon sadece
// "nereden çağrıldığı"nı taşıyor. API anahtarları (GEMINI_API_KEY,
// DEEPSEEK_API_KEY, OPENROUTER_API_KEY) yalnızca burada, Supabase Secret
// olarak duruyor — istemciye asla gitmiyor.
//
// İstek gövdesi:
//   { provider: 'gemini'|'deepseek'|'glm', model?: string, payload: <sağlayıcıya
//     aynen iletilecek JSON gövde>, deviceId: string, pageCount?: number }
// `model` yalnızca gemini için zorunlu (URL path'inde kullanılıyor); deepseek
// ve glm'de model adı payload'ın içindedir.
// `pageCount` kota sayacına eklenecek miktar (varsayılan 1).
//
// AYLIK SERT TAVAN (MONTHLY_PAGE_CAP secret'ı): kota tablosu artık yalnızca
// sayaç değil, kapı. Sağlayıcıya gitmeden ÖNCE kullanıcının bu ayki toplam
// islenen_sayfa'sı okunur; tavan aşılmışsa Gemini/DeepSeek HİÇ çağrılmaz ve
// 429 dönülür. İstemcide değişiklik gerekmedi: 429 zaten
// `FlashcardGenerationException.isQuota` üretiyor ve pipeline tüm işlemi
// durdurup kullanıcıya net "kota doldu" mesajı gösteriyor.
import { createClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_BASE_URL =
  "https://generativelanguage.googleapis.com/v1beta/models";
const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";
// GLM (z-ai/glm-4.5v) OpenRouter üzerinden çağrılır — model adı URL'de değil,
// payload'ın içinde taşınır (OpenAI-uyumlu şema).
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ProxyRequest {
  provider?: string;
  model?: string;
  payload?: unknown;
  deviceId?: string;
  pageCount?: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonError(405, "Yalnızca POST destekleniyor.");
  }

  let body: ProxyRequest;
  try {
    body = await req.json();
  } catch {
    return jsonError(400, "Geçersiz JSON gövdesi.");
  }

  const { provider, model, payload, deviceId, pageCount } = body;

  if (provider !== "gemini" && provider !== "deepseek" && provider !== "glm") {
    return jsonError(400, 'provider "gemini", "deepseek" veya "glm" olmalı.');
  }
  if (payload === undefined || payload === null) {
    return jsonError(400, "payload eksik.");
  }
  if (!deviceId || typeof deviceId !== "string") {
    return jsonError(400, "deviceId eksik.");
  }

  // KAPI: sağlayıcıya gitmeden önce aylık tavanı kontrol et. Aşılmışsa hiç
  // çağrı yapma — maliyet burada durur.
  const capped = await isOverMonthlyCap(deviceId);
  if (capped) {
    return jsonError(
      429,
      `Bu ayki kullanım sınırına (${capped.cap} sayfa) ulaştın. ` +
        `Bu ay ${capped.used} sayfa işlendi; sayaç gelecek ayın 1'inde ` +
        `sıfırlanır.`,
    );
  }

  let upstream: Response;
  try {
    if (provider === "gemini") {
      if (!model) return jsonError(400, "gemini için model gerekli.");
      const apiKey = Deno.env.get("GEMINI_API_KEY");
      if (!apiKey) {
        return jsonError(500, "Sunucu yapılandırma hatası: GEMINI_API_KEY tanımlı değil.");
      }
      upstream = await fetch(`${GEMINI_BASE_URL}/${model}:generateContent`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify(payload),
      });
    } else if (provider === "deepseek") {
      const apiKey = Deno.env.get("DEEPSEEK_API_KEY");
      if (!apiKey) {
        return jsonError(500, "Sunucu yapılandırma hatası: DEEPSEEK_API_KEY tanımlı değil.");
      }
      upstream = await fetch(DEEPSEEK_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify(payload),
      });
    } else {
      // glm — OpenRouter. DeepSeek dalıyla aynı OpenAI-uyumlu şema, tek fark
      // hedef URL ve secret adı. Aylık tavan kontrolü YUKARIDA, dallanmadan
      // ÖNCE yapıldığı için bu dala da kendiliğinden uygulanır.
      const apiKey = Deno.env.get("OPENROUTER_API_KEY");
      if (!apiKey) {
        return jsonError(500, "Sunucu yapılandırma hatası: OPENROUTER_API_KEY tanımlı değil.");
      }
      upstream = await fetch(OPENROUTER_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify(payload),
      });
    }
  } catch (e) {
    return jsonError(502, `Sağlayıcıya bağlanılamadı: ${e}`);
  }

  const bodyText = await upstream.text();

  // Kota sayacı en iyi çaba (best-effort): yalnızca başarılı istekleri
  // sayar, kayıt hatası istemciye dönecek asıl cevabı ASLA engellemez.
  if (upstream.ok) {
    logUsage(provider, deviceId, pageCount ?? 1).catch((e) => {
      console.error("kullanım kota kaydı başarısız:", e);
    });
  }

  return new Response(bodyText, {
    status: upstream.status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
});

function jsonError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/// Service role istemcisi: RLS'i bypass eder, yalnızca sunucuda kullanılır.
function serviceClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(supabaseUrl, serviceRoleKey);
}

/// İçinde bulunulan ay, 'YYYY-MM' (UTC) — kullanim_kota.ay ile aynı biçim.
function currentMonth(): string {
  return new Date().toISOString().slice(0, 7);
}

/// Aylık sayfa tavanı. Kod içine SABİT GÖMÜLMEZ: Supabase secret'ı
/// (`MONTHLY_PAGE_CAP`) olarak tanımlanır ki panelden deploy'suz
/// değiştirilebilsin. Tanımsız/geçersizse `null` → tavan devre dışı.
function monthlyPageCap(): number | null {
  const raw = Deno.env.get("MONTHLY_PAGE_CAP");
  if (!raw) return null;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    console.error(`MONTHLY_PAGE_CAP geçersiz ("${raw}") — tavan uygulanmıyor.`);
    return null;
  }
  return parsed;
}

/// Kullanıcı bu ayki tavanını doldurduysa {used, cap}, doldurmadıysa null.
///
/// Toplam TÜM sağlayıcılar üzerinden alınır (kullanim_kota'da her sağlayıcı
/// ayrı satır) — tavan kullanıcı başına, sağlayıcı başına değil.
///
/// FAIL-OPEN: tavan tanımlı değilse ya da sorgu hata verirse kullanıcı
/// ENGELLENMEZ (null döner). Geçici bir veritabanı sorunu yüzünden tüm kart
/// üretimini kilitlemek, bir kullanıcının tavanı birkaç sayfa aşmasından daha
/// kötü. Aynı "best-effort" yaklaşımı logUsage'da da var.
async function isOverMonthlyCap(
  deviceId: string,
): Promise<{ used: number; cap: number } | null> {
  const cap = monthlyPageCap();
  if (cap === null) return null;

  try {
    const { data, error } = await serviceClient()
      .from("kullanim_kota")
      .select("islenen_sayfa")
      .eq("kullanici_id", deviceId)
      .eq("ay", currentMonth());
    if (error) throw error;

    const used = (data ?? []).reduce(
      (sum: number, row: { islenen_sayfa: number | null }) =>
        sum + (row.islenen_sayfa ?? 0),
      0,
    );
    return used >= cap ? { used, cap } : null;
  } catch (e) {
    console.error("aylık tavan kontrolü başarısız (istek geçiriliyor):", e);
    return null;
  }
}

async function logUsage(
  provider: string,
  deviceId: string,
  pageCount: number,
) {
  const supabase = serviceClient();
  const ay = currentMonth();

  const { error } = await supabase.rpc("kullanim_kota_artir", {
    p_kullanici_id: deviceId,
    p_ay: ay,
    p_saglayici: provider,
    p_artis: pageCount,
  });
  if (error) throw error;
}
