use alphchemy::process_feature::process_feature_set;
use alphchemy::fetch_data::fetch_btc_ohlc;
use alphchemy::process_experiment::process_experiment;
use std::env;
use tokio::time::sleep;
use supabase_rs::SupabaseClient;
use std::time::Duration;

const POLL_INTERVAL: Duration = Duration::from_secs(2);

#[tokio::main]
async fn main() {
    let data = fetch_btc_ohlc().await.unwrap();

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

        let result = process_experiment(&client, &data).await;
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
