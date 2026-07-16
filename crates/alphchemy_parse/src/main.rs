use std::env;
use std::time::Duration;

use alphchemy_parse::process_validation::process_validation;
use supabase_rs::SupabaseClient;
use tokio::time::sleep;

const POLL_INTERVAL: Duration = Duration::from_secs(2);

fn create_client() -> SupabaseClient {
    let url_result = env::var("SUPABASE_URL");
    let url = url_result.unwrap();
    let key_result = env::var("SUPABASE_KEY");
    let key = key_result.unwrap();
    let client_result = SupabaseClient::new(url, key);
    client_result.unwrap()
}

#[tokio::main]
async fn main() {
    let client = create_client();

    loop {
        let process_result = process_validation(&client).await;
        let handled = match process_result {
            Ok(value) => value,
            Err(error) => {
                println!("{error}");
                false
            }
        };
        if handled {
            continue;
        }

        println!("idle");
        sleep(POLL_INTERVAL).await;
    }
}
