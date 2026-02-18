import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ========== AUTH HELPER ==========
async function requireAuth(req: Request): Promise<{ userId: string; error?: undefined } | { userId?: undefined; error: Response }> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return { error: new Response(JSON.stringify({ error: "Não autorizado" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }) };
  }
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) {
    return { error: new Response(JSON.stringify({ error: "Sessão inválida" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }) };
  }
  return { userId: data.user.id };
}

// Enums definidos para análise detalhada (mantidos para o prompt)
const CATEGORIES = ["vestido", "blazer", "calça", "camisa", "saia", "conjunto", "short", "casaco", "macacão", "blusa", "regata", "cropped", "top", "body"];
const COLORS = ["preto", "branco", "bege", "rosa", "azul", "verde", "vermelho", "marrom", "cinza", "amarelo", "laranja", "roxo", "vinho", "nude", "off white", "creme", "dourado", "prata", "estampado", "floral", "animal print", "listrado", "xadrez"];
const STYLES = ["minimal", "clássico", "moderno", "romântico", "fashion", "sexy_chic", "elegante", "casual", "boho", "streetwear", "preppy", "sofisticado"];
const OCCASIONS = ["trabalho", "casual_chic", "festa", "eventos", "viagem", "dia_a_dia", "praia", "happy_hour", "formal"];
const MODELINGS = ["regular", "acinturado", "oversized", "slim", "reto", "amplo", "ajustado", "soltinho", "evasê", "godê", "lápis", "trapézio"];
const NECKLINES = ["V", "quadrado", "redondo", "alto", "ombro a ombro", "tomara que caia", "decote canoa", "gola rolê", "decote profundo", "sem decote"];
const SLEEVES = ["sem manga", "regata", "alça fina", "alça larga", "manga curta", "manga 3/4", "manga longa", "manga bufante", "manga sino", "ombro caído"];
const LENGTHS = ["mini", "curto", "midi", "longo", "cropped"];
const TEXTURES = ["alfaiataria", "malha", "cetim", "seda", "linho", "jeans", "couro", "renda", "tricô", "veludo", "chiffon", "crepe", "viscose"];

interface DetailedAnalysisResult {
  categoria: { value: string | null; confidence: number; alternatives?: string[] };
  cor: { value: string | null; confidence: number; alternatives?: string[]; cor_secundaria?: string };
  estilo: { value: string | null; confidence: number; alternatives?: string[] };
  ocasiao: { value: string | null; confidence: number; alternatives?: string[] };
  modelagem: { value: string | null; confidence: number; alternatives?: string[] };
  decote: { value: string | null; confidence: number };
  manga_alca: { value: string | null; confidence: number };
  comprimento: { value: string | null; confidence: number };
  textura: { value: string | null; confidence: number };
  tags_extras: string[];
  resumo_visual: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  // ========== AUTH CHECK ==========
  const auth = await requireAuth(req);
  if (auth.error) return auth.error;

  try {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return new Response(JSON.stringify({ error: "Corpo da requisição inválido" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const image_base64 = typeof body.image_base64 === "string" ? body.image_base64 : undefined;
    const image_url = typeof body.image_url === "string" ? body.image_url : undefined;

    if (!image_base64 && !image_url) {
      return new Response(
        JSON.stringify({ error: "image_base64 ou image_url é obrigatório" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate URL format if provided
    if (image_url && !image_url.startsWith("http")) {
      return new Response(JSON.stringify({ error: "image_url deve ser uma URL válida" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Validate base64 size (max ~10MB)
    if (image_base64 && image_base64.length > 15_000_000) {
      return new Response(JSON.stringify({ error: "Imagem muito grande (máx 10MB)" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ========== OPENAI KEY ==========
    const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
    if (!OPENAI_API_KEY) {
      throw new Error("OPENAI_API_KEY não configurada no Supabase");
    }

    const systemPrompt = `Você é um especialista em moda e análise de vestuário feminino brasileiro. Analise a imagem de roupa/peça fornecida e retorne um JSON DETALHADO.

IMPORTANTE: Retorne APENAS o JSON válido, sem markdown, sem explicações adicionais.

Campos obrigatórios e valores sugeridos (mas use o que ver na imagem com precisão):
- categoria: UM destes: ${CATEGORIES.join(", ")}
- cor: objeto com:
  - value: cor principal (${COLORS.join(", ")})
  - confidence: 0.1 a 1.0
  - cor_secundaria: cor secundária se houver (opcional)
- estilo: UM destes: ${STYLES.join(", ")}
- ocasiao: UM destes: ${OCCASIONS.join(", ")} (seja assertivo)
- modelagem: UM destes: ${MODELINGS.join(", ")}
- decote: UM destes: ${NECKLINES.join(", ")}
- manga_alca: UM destes: ${SLEEVES.join(", ")}
- comprimento: UM destes: ${LENGTHS.join(", ")}
- textura: UM destes (se identificável): ${TEXTURES.join(", ")}
- tags_extras: array de 3-6 tags descritivas curtas e únicas (ex: "botões dourados", "fenda lateral")
- resumo_visual: frase CURTA (máx 20 palavras) descrevendo a peça de forma natural

Exemplo de formato JSON esperado:
{
  "categoria": { "value": "blusa", "confidence": 0.95 },
  "cor": { "value": "amarelo", "confidence": 0.9, "cor_secundaria": "dourado" },
  "estilo": { "value": "minimal", "confidence": 0.85 },
  "ocasiao": { "value": "trabalho", "confidence": 0.8 },
  "modelagem": { "value": "ajustado", "confidence": 0.85 },
  "decote": { "value": "V", "confidence": 0.9 },
  "manga_alca": { "value": "alça fina", "confidence": 0.85 },
  "comprimento": { "value": "cropped", "confidence": 0.8 },
  "textura": { "value": "cetim", "confidence": 0.7 },
  "tags_extras": ["decote V", "minimalista", "elegante", "tom pastel", "verão"],
  "resumo_visual": "Blusa cropped amarela com alça fina e decote V, estilo minimalista elegante"
}`;

    // Prepare the image content for the OpenAI API
    let imageUrlContent: string;

    if (image_base64) {
      // Check if it has prefix
      if (image_base64.startsWith("data:")) {
        imageUrlContent = image_base64;
      } else {
        // Assume jpeg if raw base64
        imageUrlContent = `data:image/jpeg;base64,${image_base64}`;
      }
    } else {
      imageUrlContent = image_url!;
    }

    console.log("Calling OpenAI GPT-4o-mini for image analysis...");

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-4o-mini", // Using mini for speed and cost efficiency
        messages: [
          { role: "system", content: systemPrompt },
          {
            role: "user",
            content: [
              { type: "text", text: "Analise esta peça de roupa feminina e retorne o JSON detalhado." },
              { type: "image_url", image_url: { url: imageUrlContent, detail: "high" } }
            ]
          }
        ],
        max_tokens: 1000,
        temperature: 0.2, // Low temperature for more deterministic JSON
        response_format: { type: "json_object" } // Enforce JSON mode
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("OpenAI API error:", response.status, errorText);
      if (response.status === 429) return new Response(JSON.stringify({ error: "Limite de requisições excedido na OpenAI." }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      if (response.status === 401) return new Response(JSON.stringify({ error: "Chave da OpenAI inválida." }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      throw new Error(`OpenAI API error: ${response.status}`);
    }

    const aiResponse = await response.json();
    const content = aiResponse.choices?.[0]?.message?.content;

    if (!content) {
      console.error("Empty content from AI");
      throw new Error("Resposta vazia da IA");
    }

    let analysis: DetailedAnalysisResult;
    try {
      analysis = JSON.parse(content);
    } catch (e) {
      console.error("Failed to parse JSON from OpenAI:", content);
      throw new Error("IA retornou formato inválido");
    }

    // Fallback for resumo_visual if missing
    if (!analysis.resumo_visual) {
      const cat = analysis.categoria?.value || "peça";
      const cor = analysis.cor?.value || "";
      const estilo = analysis.estilo?.value || "";
      analysis.resumo_visual = `${cat} ${cor} com estilo ${estilo}`.trim();
    }

    return new Response(JSON.stringify({ success: true, analysis }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    console.error("Error in analyze-product-image:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Erro ao analisar imagem" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
