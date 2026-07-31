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
