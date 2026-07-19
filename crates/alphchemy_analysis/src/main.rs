use std::env::var;
use std::time::Duration;

use alphchemy_analysis::tools::notebook_tools::process_working_notebook;
use rust_supabase_sdk::SupabaseClient;
use tokio::time::sleep;

#[tokio::main]
async fn main() -> Result<(), String> {
    let supabase_url = var("SUPABASE_URL");
    let supabase_url = supabase_url.map_err(|error| error.to_string())?;
    let supabase_key = var("SUPABASE_KEY");
    let supabase_key = supabase_key.map_err(|error| error.to_string())?;
    let supabase = SupabaseClient::new(supabase_url, supabase_key, None);

    loop {
        if process_working_notebook(&supabase).await? {
            continue;
        }

        println!("idle");
        sleep(Duration::from_secs(2)).await;
    }
}
