use redis::Commands;

use alphchemy::experiment::experiment::run_experiment_json;
use alphchemy::utils::read_ohlc_data;
use redis::Client;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let data_path = "data/btc_data.csv";
    let ohlc_result = read_ohlc_data(data_path);
    let (close_prices, ohlc_data) = ohlc_result
        .map_err(|err| -> Box<dyn std::error::Error> { err.into() })?;

    let mut conn = Client::open("redis://localhost:6379")?.get_connection()?;

    loop {
        println!("waiting");

        let pop_result = conn.brpop::<&str, (String, String)>("experiments", 0.0)?;
        let experiment_data = pop_result.1;

        let experiment_json: serde_json::Value = match serde_json::from_str(&experiment_data) {
            Ok(json) => json,
            Err(err) => {
                println!("Error parsing experiment data: {err}");
                continue;
            }
        };

        let title_json = experiment_json.get("title");
        let maybe_title = title_json.and_then(|val| val.as_str());
        let title = maybe_title.unwrap_or("unknown");
        println!("running {title}");

        let results = run_experiment_json(&experiment_json, &close_prices, &ohlc_data);

        let entry_json = serde_json::json!({
            "experiment": experiment_json,
            "results": results
        });

        let entry_str = serde_json::to_string(&entry_json)?;

        let push_result: Result<(), _> = conn.lpush("results", &entry_str);
        if let Err(err) = push_result {
            println!("Internal error occurred when processing JSON");
            println!("{err}");
        }
    }
}
