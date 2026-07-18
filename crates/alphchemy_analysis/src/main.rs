use std::time::Duration;

use alphchemy_analysis::analysis::{process_working_notebook, supabase_from_env};
use tokio::time::sleep;

#[tokio::main]
async fn main() -> Result<(), String> {
    let supabase = supabase_from_env()?;

    loop {
        if process_working_notebook(&supabase).await? {
            continue;
        }

        println!("idle");
        sleep(Duration::from_secs(2)).await;
    }
}
