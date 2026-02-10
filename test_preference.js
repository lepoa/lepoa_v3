
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    console.log("Please run this script using `supabase functions serve` or similar environment.");
    process.exit(1);
}

// We'll simulate fetching the last order ID first
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(supabaseUrl, supabaseKey);

async function testCreatePreference() {
    console.log("Fetching last order...");
    const { data: orders, error } = await supabase
        .from('orders')
        .select('id, total, status')
        .order('created_at', { ascending: false })
        .limit(1);

    if (error || !orders || orders.length === 0) {
        console.error("Error fetching order:", error);
        return;
    }

    const lastOrder = orders[0];
    console.log("Last order found:", lastOrder);

    if (lastOrder.status === 'pago') {
        console.log("Order already paid. Skipping preference creation.");
        return;
    }

    console.log("Invoking create-mp-preference for order:", lastOrder.id);

    // Directly invoke the function via fetch to simulate client call
    // Note: In real life this would need auth headers, but we can test logic if we bypass auth check or provide service role
    // Actually, let's just use the supabase client's invoke method if possible
    // But we are in node environment here, so `supabase.functions.invoke` works differently.

    // Instead, let's just inspect the database to see WHY update failed if previous calls failed.
    // We can't really debug the edge function from here easily without logs.

    console.log("Please check Supabase Edge Function logs for `create-mp-preference` invocation errors.");
}

testCreatePreference();
