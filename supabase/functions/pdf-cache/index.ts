// MedKart pdf-cache Edge Function
//
// Paylaşılan PDF→kart önbelleği: aynı PDF (SHA-256 hash'i) birden fazla
// öğrenci tarafından yüklenirse, ikinci ve sonraki yüklemeler Gemini'a hiç
// gitmeden burada saklanan kartlarla anında karşılanır. Kullanıcıya özel
// DEĞİL — tüm kullanıcılar için paylaşılan tek bir önbellek (`pdf_cache`
// tablosu, bkz. migration).
//
// İstemci `ai-proxy`'den ayrı bu fonksiyonu çağırır (o yalnızca Gemini/
// DeepSeek proxy'si, cache mantığı karıştırılmadı). RLS kilitli tabloya
// yalnızca burada, service_role ile erişilir.
//
// İstek gövdesi:
//   { action: 'lookup', hash: string, min_prompt_version?: string }
//   { action: 'save', hash: string, cards: unknown[], model_version?: string, prompt_version?: string }
//
// PROMPT SÜRÜMÜ ARTIK İŞLEVSEL (2026-08-17). Öncesinde yalnızca kaydediliyordu
// ve lookup hiç filtrelemiyordu; sonuç olarak önbellekteki kayıtların hepsi
// eski prompt sürümlerinden kalmıştı ve bir isabet, o günden beri eklenmiş
// kalite kurallarının hiçbirini taşımayan kartları servis ediyordu. İki
// değişiklik BİRLİKTE yapıldı — biri diğeri olmadan işe yaramaz:
//
//   1) lookup: `min_prompt_version`'dan ESKİ (ya da sürümsüz) kayıt
//      İSABET SAYILMAZ (`found: false`) ve hit sayacı ARTIRILMAZ.
//   2) save:   eldekinden DAHA YENİ bir sürüm gelirse kayıt EZİLİR.
//      Eskiden `ignoreDuplicates: true` ("ilk kaydeden kazanır") idi —
//      yalnızca (1) yapılsaydı bayat kayıt sonsuza kadar kalır, her
//      kullanıcı yeniden üretir (tam maliyet) ve önbellek ASLA kendini
//      onaramazdı. Yani bu ikisi ayrılamaz.
//
// Eşik SUNUCUDA SABİT DEĞİL, istemciden geliyor (bkz. Flutter tarafında
// `flashcard_prompt.dart` `kMinCacheablePromptVersion`): politika prompt
// kurallarının yanında duruyor ve değiştirmek bu fonksiyonu yeniden deploy
// etmeyi GEREKTİRMİYOR. `min_prompt_version` gönderilmezse filtre uygulanmaz
// (eski istemcilerle geriye dönük uyumlu).
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface CacheRequest {
  action?: string;
  hash?: string;
  cards?: unknown[];
  model_version?: string;
  prompt_version?: string;
  min_prompt_version?: string;
}

// 'v27' -> 27. Sürüm yoksa/çözülemiyorsa null ("en eski" sayılır).
// Flutter tarafında `flashcard_prompt.dart` `promptVersionNumber` ile AYNI
// mantık — birini değiştirirsen diğerini de hizala.
function promptVersionNumber(version?: string | null): number | null {
  if (typeof version !== "string") return null;
  const m = /^v(\d+)$/.exec(version.trim());
  if (m === null) return null;
  const n = Number.parseInt(m[1], 10);
  return Number.isFinite(n) ? n : null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonError(405, "Yalnızca POST destekleniyor.");
  }

  let body: CacheRequest;
  try {
    body = await req.json();
  } catch {
    return jsonError(400, "Geçersiz JSON gövdesi.");
  }

  const { action, hash, cards, model_version, prompt_version, min_prompt_version } =
    body;

  if (!hash || typeof hash !== "string") {
    return jsonError(400, "hash eksik.");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  if (action === "lookup") {
    const { data, error } = await supabase
      .from("pdf_cache")
      .select("generated_cards, hit_count, prompt_version")
      .eq("hash", hash)
      .maybeSingle();

    if (error) return jsonError(500, `Önbellek okunamadı: ${error.message}`);

    if (data === null) {
      return jsonOk({ found: false, cards: null, hit_count: null });
    }

    // BAYAT KAYIT = İSABET DEĞİL. Sayaç da ARTIRILMAZ (gerçekten
    // kullanılmadı) — yoksa hit_count gerçeği yansıtmaz.
    const minVersion = promptVersionNumber(min_prompt_version);
    if (minVersion !== null) {
      const stored = promptVersionNumber(data.prompt_version);
      if (stored === null || stored < minVersion) {
        return jsonOk({
          found: false,
          cards: null,
          hit_count: null,
          stale: true,
          stored_prompt_version: data.prompt_version ?? null,
        });
      }
    }

    // HIT — sayacı atomik artır (RPC, bkz. migration). Artırım başarısız
    // olursa (nadiren) HIT'i yine de karşıla, sayaç olarak eski değere düş —
    // kullanıcının kartları alması sayaç gösteriminden ÖNEMLİ.
    const { data: newHitCount, error: incError } = await supabase.rpc(
      "pdf_cache_hit_artir",
      { p_hash: hash },
    );

    return jsonOk({
      found: true,
      cards: data.generated_cards,
      hit_count: incError ? data.hit_count : newHitCount,
    });
  }

  if (action === "save") {
    if (!Array.isArray(cards)) {
      return jsonError(400, "save için cards (dizi) gerekli.");
    }
    // ESKİDEN "ilk kaydeden kazanır" (`ignoreDuplicates: true`) idi. Artık
    // SÜRÜM KARŞILAŞTIRILIYOR: gelen sürüm eldekinden DAHA YENİYSE kayıt
    // ezilir, değilse dokunulmaz. Bu olmadan lookup filtresi işe yaramazdı —
    // bayat kayıt yerinde kalır, her kullanıcı yeniden üretir ve önbellek
    // asla tazelenmezdi.
    //
    // Eşit sürümde de dokunmuyoruz: aynı PDF + aynı prompt = aynı içerik
    // kabul edilir, gereksiz yazma yok (eski davranışın korunan kısmı).
    const { data: mevcut, error: readError } = await supabase
      .from("pdf_cache")
      .select("prompt_version")
      .eq("hash", hash)
      .maybeSingle();

    if (readError) {
      return jsonError(500, `Önbellek okunamadı: ${readError.message}`);
    }

    if (mevcut !== null) {
      const gelen = promptVersionNumber(prompt_version);
      const eldeki = promptVersionNumber(mevcut.prompt_version);
      // Gelen sürüm çözülemiyorsa ASLA ezme (sürümsüz bir kayıt, sürümlü
      // bir kaydın yerini almamalı).
      const dahaYeni = gelen !== null && (eldeki === null || gelen > eldeki);
      if (!dahaYeni) return jsonOk({ ok: true, skipped: "not_newer" });
    }

    const { error } = await supabase.from("pdf_cache").upsert(
      {
        hash,
        generated_cards: cards,
        model_version: model_version ?? null,
        prompt_version: prompt_version ?? null,
      },
      // `ignoreDuplicates: false` = çakışmada GÜNCELLE. Yukarıdaki kontrol
      // zaten yalnızca daha yeni sürümlerin buraya ulaşmasını sağlıyor.
      // NOT: `hit_count` payload'da OLMADIĞI için ON CONFLICT DO UPDATE
      // onu değiştirmez — sayaç korunur (o, PDF'in popülerliğini ölçüyor,
      // içeriğin sürümünü değil).
      { onConflict: "hash", ignoreDuplicates: false },
    );

    if (error) return jsonError(500, `Önbelleğe yazılamadı: ${error.message}`);
    return jsonOk({ ok: true, written: true });
  }

  return jsonError(400, 'action "lookup" veya "save" olmalı.');
});

function jsonOk(payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function jsonError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
