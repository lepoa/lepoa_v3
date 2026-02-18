SELECT id, name, whatsapp, created_at 
FROM profiles 
WHERE 
  whatsapp LIKE '%982691262%' 
  OR name ILIKE '%Ana Carolina%'
  OR name ILIKE '%Laís%'
ORDER BY created_at DESC;
