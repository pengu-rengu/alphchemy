use alphchemy::process_feature::process_feature_set;
use alphchemy::fetch_data::fetch_btc_ohlc;
use alphchemy::process_experiment::process_experiment;
use chrono::Utc;
use std::env;
use tokio::time::sleep;
use supabase_rs::SupabaseClient;
use std::time::Duration;

const POLL_INTERVAL: Duration = Duration::from_secs(2);
const STARTUP_WINDOW_SECS: f64 = 3_600_000.0;

#[tokio::main]
async fn main() {
    let now = Utc::now();
    let now_seconds = now.timestamp() as f64;
    let startup_start = now_seconds - STARTUP_WINDOW_SECS;
    let data = fetch_btc_ohlc(startup_start, now_seconds).await.unwrap();

    let url = env::var("SUPABASE_URL").unwrap();
    let key = env::var("SUPABASE_KEY").unwrap();
    let client = SupabaseClient::new(url, key).unwrap();

    loop {
        let feature_set_result = process_feature_set(&client, &data).await;
        let handled_feature_sets = match feature_set_result {
            Ok(value) => value,
            Err(error) => {
                println!("{}", error);
                false
            }
        };
        if handled_feature_sets {
            continue;
        }

        let result = process_experiment(&client).await;
        let next  = match result {
            Ok(value) => value,
            Err(error) => {
                println!("{}", error);
                false
            }
        };
        if next {
            continue;
        }

        println!("idle");
        sleep(POLL_INTERVAL).await;
    }
}
