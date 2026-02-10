# Solução Definitiva para o Erro de Pagamento

Identificamos que o erro `Edge Function returned a non-2xx status code` persiste porque o servidor (Supabase Cloud ou Local) **ainda está rodando a versão antiga** da função de pagamento, que não possui o tratamento de erros que implementamos.

Para corrigir isso, você precisa atualizar a função no servidor. Siga os passos abaixo:

## Passo 1: Atualizar a Edge Function (Deploy)

Abra um terminal na pasta do projeto (`c:\seuprovador`) e execute o comando abaixo para enviar o código corrigido para a nuvem:

```bash
npx supabase functions deploy create-mp-preference
```

> **Nota:** Se você não estiver logado, o comando pedirá para você fazer login com sua conta Supabase.

Se estiver rodando **localmente** (não na nuvem), reinicie o servidor:
ctrl+c (para parar)
`npx supabase start`

## Passo 2: Verificar Variáveis de Ambiente (Segredos)

A função precisa das chaves para funcionar. Se você estiver usando a **Supabase Cloud**, vá no painel:

1. Acesse seu projeto no [Supabase Dashboard](https://supabase.com/dashboard).
2. Vá em **Edge Functions** (menu lateral).
3. Clique em `create-mp-preference` (se ela aparecer na lista) ou vá em **Settings > Secrets** (se for global).
4. Certifique-se de que os seguintes segredos (Secrets) estão configurados:
   - `MERCADOPAGO_ACCESS_TOKEN` (Seu token de produção ou teste do MP)
   - `SUPABASE_URL` (URL do projeto)
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`

Se estiver rodando **localmente**, verifique se o arquivo `.env` na raiz tem essas chaves.

## Passo 3: Testar Novamente

Após o deploy bem-sucedido (passo 1), volte ao site, atualize a página (F5) e clique em "Pagar agora".

- **Se funcionar:** Você será redirecionado para o Mercado Pago.
- **Se falhar:** A mensagem de erro agora será específica (ex: "Mercado Pago não configurado"), permitindo a correção imediata.
