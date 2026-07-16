use serde_json::Value;

pub fn get_field<'a>(json: &'a Value, key: &str) -> Result<&'a Value, String> {
    let maybe_value = json.get(key);
    maybe_value.ok_or_else(|| format!("missing {key}"))
}

pub fn field_f64(json: &Value, key: &str) -> Result<f64, String> {
    let maybe_value = get_field(json, key)?.as_f64();
    maybe_value.ok_or_else(|| format!("{key} must be f64"))
}

pub fn field_usize(json: &Value, key: &str) -> Result<usize, String> {
    let maybe_value = get_field(json, key)?.as_u64();
    let value = maybe_value.ok_or_else(|| format!("{key} must be u64"))?;
    Ok(value as usize)
}

pub fn field_str<'a>(json: &'a Value, key: &str) -> Result<&'a str, String> {
    let maybe_value =  get_field(json, key)?.as_str();
    maybe_value.ok_or_else(|| format!("{key} must be string"))
}

pub fn field_string(json: &Value, key: &str) -> Result<String, String> {
    Ok(field_str(json, key)?.to_string())
}

pub fn field_array<'a>(json: &'a Value, key: &str) -> Result<&'a Vec<Value>, String> {
    let maybe_value = get_field(json, key)?.as_array();
    maybe_value.ok_or_else(|| format!("{key} must be array"))
}

pub fn validate_identifier(id: &str, field: &str) -> Result<(), String> {
    if id.is_empty() {
        return Err(format!("{field} must not be empty"));
    }
    for character in id.chars() {
        if !character.is_ascii_alphanumeric() && character != '_' {
            return Err(format!("{field} {id} contains invalid pinescript identifier character {character}"));
        }
    }
    Ok(())
}

pub fn expect_non_neg(value: f64, field: &str) -> Result<(), String> {
    if value < 0.0 {
        return Err(format!("{field} must be >= 0.0"));
    }
    Ok(())
}
