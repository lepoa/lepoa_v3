import re

# Read the file
with open('supabase/functions/mp-webhook/index.ts', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace .insert({ with .upsert({, { onConflict: 'live_cart_id' })
# Find the specific insert for orders table around line 416-418
pattern = r'(const \{ data: newOrder, error: orderError \} = await supabase\s+\.from\("orders"\)\s+)\.insert\('
replacement = r'\1.upsert('

content = re.sub(pattern, replacement, content, count=1)

# Also need to add the onConflict parameter before .select()
# Find: }).select().single();
# Replace with: }, { onConflict: 'live_cart_id' }).select().single();
pattern2 = r'(seller_id: liveCart\.seller_id \|\| null,\s+\})\s+\)(\s+\.select\(\)\s+\.single\(\);)'
replacement2 = r'\1, { onConflict: "live_cart_id" })\2'

content = re.sub(pattern2, replacement2, content, count=1)

# Write back
with open('supabase/functions/mp-webhook/index.ts', 'w', encoding='utf-8') as f:
    f.write(content)

print("File updated successfully!")
