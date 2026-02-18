import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

const PREMIUM_COPYWRITER_PROMPT = `Você é uma especialista em moda e copywriter premium da Le.Poá.
Sua tarefa é gerar uma descrição de produto MUITO completa e fiel à foto enviada, sem inventar informações que não estejam visíveis.

Obrigatório analisar a imagem e citar detalhes reais, como: tipo da peça, cor, acabamento, recortes, contraste, estilo, proposta e como valoriza o look.

Regras importantes:

1. Se a peça for um "spencer" (blazer curto estruturado), use o termo "Spencer" e explique o efeito dele no corpo.
2. Se houver detalhes em preto, mencione como "vivo/contorno" ou "acabamento contrastante".
3. Se for bicolor, escreva "bicolor" e explique o impacto visual (sofisticado, elegante, marcante).
4. Não fale de tecido específico (ex: alfaiataria, linho, crepe) se não for possível confirmar pela imagem.
5. Use linguagem elegante e prática, com tom de consultoria de imagem.
6. Sempre incluir o nome "Le.Poá" no texto de forma natural (SEO).

Retorne APENAS um JSON válido (sem markdown, sem explicações) com esta estrutura exata:

{
  "nome_produto": "Nome curto e forte para o produto",
  "descricao_completa": "Descrição completa para o site",
  "diferenciais": ["Diferencial 1", "Diferencial 2", "Diferencial 3", "Diferencial 4"],
  "frase_anuncio": "Frase curta para anúncio sem emojis",
  "palavras_chave": ["palavra1", "palavra2", "palavra3", "palavra4", "palavra5"]
}`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const auth = await requireAuth(req);
  if (auth.error) return auth.error;

  try {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return new Response(JSON.stringify({ error: "Corpo da requisição inválido" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const image_url = typeof body.image_url === "string" ? body.image_url : undefined;
    const image_base64 = typeof body.image_base64 === "string" ? body.image_base64 : undefined;
    const product_name = typeof body.product_name === "string" ? body.product_name.slice(0, 200) : undefined;

    if (!image_url && !image_base64) {
      return new Response(JSON.stringify({ error: "image_url ou image_base64 é obrigatório" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Validate URL format if provided
    if (image_url && !image_url.startsWith("http")) {
      return new Response(JSON.stringify({ error: "image_url deve ser uma URL válida" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Validate base64 size (max ~10MB)
    if (image_base64 && image_base64.length > 15_000_000) {
      return new Response(JSON.stringify({ error: "Imagem muito grande (máx 10MB)" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
    if (!OPENAI_API_KEY) throw new Error("OPENAI_API_KEY não configurada");

    // Prepare image for OpenAI
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

    const userPrompt = product_name
      ? `Analise esta peça de roupa feminina chamada "${product_name}" e gere a descrição premium completa seguindo o formato JSON solicitado.`
      : `Analise esta peça de roupa feminina e gere a descrição premium completa seguindo o formato JSON solicitado.`;

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "gpt-4o-mini", // Cost effective, high quality
        messages: [
          { role: "system", content: PREMIUM_COPYWRITER_PROMPT },
          {
            role: "user",
            content: [
              { type: "text", text: userPrompt },
              { type: "image_url", image_url: { url: imageUrlContent, detail: "high" } }
            ]
          }
        ],
        max_tokens: 2000,
        temperature: 0.7, // Higher creativity for descriptions
        response_format: { type: "json_object" }
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("OpenAI API error:", response.status, errorText);
      if (response.status === 429) return new Response(JSON.stringify({ error: "Limite de requisições excedido." }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      if (response.status === 401) return new Response(JSON.stringify({ error: "Chave da OpenAI inválida." }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      throw new Error(`OpenAI API error: ${response.status}`);
    }

    const aiResponse = await response.json();
    const content = aiResponse.choices?.[0]?.message?.content;
    if (!content) throw new Error("Resposta vazia da IA");

    let result;
    try {
      result = JSON.parse(content);
    } catch {
      console.error("Failed to parse JSON:", content);
      // Fallback in case JSON is malformed
      return new Response(JSON.stringify({ success: true, data: { nome_produto: product_name || "Peça Le.Poá", descricao_completa: content, diferenciais: [], frase_anuncio: "", palavras_chave: [] } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ success: true, data: result }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    console.error("Error in generate-product-description:", error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Erro ao gerar descrição" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
