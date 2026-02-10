
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = "https://deibjfkveiyogvtscyeh.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlaWJqZmt2ZWl5b2d2dHNjeWVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2MDA3MzMsImV4cCI6MjA4NjE3NjczM30.eYGXOHLLJq6wpRT605kxSc8t_qS15_ux174d0rUOmfY";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function checkUser() {
    console.log('Checking live_customers for laistmelo...');
    try {
        const { data, error } = await supabase
            .from('live_customers')
            .select('id, instagram_handle, whatsapp, nome')
            .ilike('instagram_handle', '%laistmelo%');

        if (error) {
            console.error('Error fetching:', error);
        } else {
            console.log('Found customers:', JSON.stringify(data, null, 2));
        }
    } catch (err) {
        console.error('Unexpected error:', err);
    }
}

checkUser();
