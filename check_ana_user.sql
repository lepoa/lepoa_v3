
-- Tenta achar a Ana na tabela de usuários (profiles ou auth.users)

-- PROFILES (tabela pública de usuários)
SELECT * FROM profiles 
WHERE 
    full_name ILIKE '%ana%' 
    OR email ILIKE '%ana%'
    OR phone ILIKE '%982797213%' -- final do telefone do print
    OR whatsapp ILIKE '%982797213%';

-- AUTH.USERS (tabela de autenticação - só admin vê)
SELECT id, email, phone, last_sign_in_at 
FROM auth.users 
WHERE 
    email ILIKE '%ana%' 
    OR phone LIKE '%982797213%';
