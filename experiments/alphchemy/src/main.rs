//use alphchemy::process_feature_set::process_feature_set;
use alphchemy::process_experiment::process_experiment;
use alphchemy::process_pinescript::process_pinescript;
use alphchemy::process_validation::process_validation;
use std::env;
use tokio::time::sleep;
use supabase_rs::SupabaseClient;
use std::time::Duration;

const POLL_INTERVAL: Duration = Duration::from_secs(2);

#[tokio::main]
async fn main() {
    let url = env::var("SUPABASE_URL").unwrap();
    let key = env::var("SUPABASE_KEY").unwrap();
    let client = SupabaseClient::new(url, key).unwrap();

    loop {
        /*
        let feature_set_result = process_feature_set(&client).await;
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
        */

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

        let pinescript_result = process_pinescript(&client).await;
        let handled_pinescript = match pinescript_result {
            Ok(value) => value,
            Err(error) => {
                println!("{}", error);
                false
            }
        };
        if handled_pinescript {
            continue;
        }

        let validation_result = process_validation(&client).await;
        let handled_validation = match validation_result {
            Ok(value) => value,
            Err(error) => {
                println!("{}", error);
                false
            }
        };
        if handled_validation {
            continue;
        }

        println!("idle");
        sleep(POLL_INTERVAL).await;
    }
}
