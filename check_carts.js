
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = "https://deibjfkveiyogvtscyeh.supabase.co";
const supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlaWJqZmt2ZWl5b2d2dHNjeWVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2MDA3MzMsImV4cCI6MjA4NjE3NjczM30.eYGXOHLLJq6wpRT605kxSc8t_qS15_ux174d0rUOmfY";
const supabase = createClient(supabaseUrl, supabaseKey);

async function listCustomers() {
    console.log("Listing recent customers...");

    const { data: customers, error } = await supabase
        .from("live_customers")
        .select("instagram_handle, created_at, live_event_id")
        .order("created_at", { ascending: false })
        .limit(20);

    if (error) {
        console.error("Error:", error);
        return;
    }

    console.log("Recent customers:", customers);
}

listCustomers();
