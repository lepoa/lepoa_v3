
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function fixAdmin() {
  const email = "comercial@lepoa.com.br";
  
  // 1. Get the user ID from Auth
  const { data: { users }, error } = await supabase.auth.admin.listUsers();
  
  if (error || !users) {
    console.error("Erro ao listar usuários:", error);
    return;
  }

  const user = users.find(u => u.email === email);
  
  if (!user) {
    console.error(`Usuário ${email} não encontrado no Auth! Crie ele no painel primeiro.`);
    return;
  }

  console.log(`Usuário encontrado: ${user.id}`);

  // 2. Check if user_roles table exists and insert role
  // Since we don't know if the table exists (it might be public.user_roles or auth.user_roles or expected via relation)
  // But the code says: .from("user_roles").select("role")
  // So it's a public table.

  const { error: insertError } = await supabase
    .from("user_roles")
    .insert({ user_id: user.id, role: "admin" });

  if (insertError) {
    console.error("Erro ao inserir role:", insertError);
    // If table doesn't exist, we might need to create it? But schema should be there.
  } else {
    console.log("✅ Sucesso! Papel de 'admin' atribuído ao usuário.");
  }
}

fixAdmin();
