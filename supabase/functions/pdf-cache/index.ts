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
//   { action: 'lookup', hash: string }
//   { action: 'save', hash: string, cards: unknown[], model_version?: string, prompt_version?: string }
//
// model_version/prompt_version ŞİMDİLİK yalnızca kaydediliyor (ileride
// prompt/model güncellenince eski cache girdilerini ayırt edebilmek için,
// bkz. Flutter tarafında `flashcard_prompt.dart` `kPromptVersion`) —
// lookup bu değerlere göre HİÇBİR filtreleme yapmıyor, davranış değişmedi.
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

  const { action, hash, cards, model_version, prompt_version } = body;

  if (!hash || typeof hash !== "string") {
    return jsonError(400, "hash eksik.");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  if (action === "lookup") {
    const { data, error } = await supabase
      .from("pdf_cache")
      .select("generated_cards, hit_count")
      .eq("hash", hash)
      .maybeSingle();

    if (error) return jsonError(500, `Önbellek okunamadı: ${error.message}`);

    if (data === null) {
      return jsonOk({ found: false, cards: null, hit_count: null });
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
    // Aynı hash zaten kayıtlıysa dokunma (ilk kaydeden kazanır, tekrar
    // yazmak gereksiz — içerik aynı PDF'ten geldiği için içerik de aynı
    // kabul edilir).
    const { error } = await supabase
      .from("pdf_cache")
      .upsert(
        {
          hash,
          generated_cards: cards,
          model_version: model_version ?? null,
          prompt_version: prompt_version ?? null,
        },
        { onConflict: "hash", ignoreDuplicates: true },
      );

    if (error) return jsonError(500, `Önbelleğe yazılamadı: ${error.message}`);
    return jsonOk({ ok: true });
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
