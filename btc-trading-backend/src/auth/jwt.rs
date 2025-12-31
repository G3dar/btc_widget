use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: String,        // Device ID
    pub exp: i64,           // Expiration time
    pub iat: i64,           // Issued at
    pub device_name: String, // Device name for identification
}

/// Create a new JWT token
pub fn create_token(
    device_id: &str,
    device_name: &str,
    secret: &str,
    expiry_minutes: i64,
) -> Result<String, jsonwebtoken::errors::Error> {
    let now = Utc::now();
    let expiry = now + Duration::minutes(expiry_minutes);

    let claims = Claims {
        sub: device_id.to_string(),
        exp: expiry.timestamp(),
        iat: now.timestamp(),
        device_name: device_name.to_string(),
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
}

/// Validate a JWT token and return claims
pub fn validate_token(token: &str, secret: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )?;

    Ok(token_data.claims)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_and_validate_token() {
        let secret = "test_secret_key_12345";
        let device_id = "device_123";
        let device_name = "iPhone 15 Pro";

        let token = create_token(device_id, device_name, secret, 15).unwrap();

        let claims = validate_token(&token, secret).unwrap();

        assert_eq!(claims.sub, device_id);
        assert_eq!(claims.device_name, device_name);
    }

    #[test]
    fn test_invalid_token() {
        let secret = "test_secret_key_12345";
        let wrong_secret = "wrong_secret";

        let token = create_token("device", "iPhone", secret, 15).unwrap();

        let result = validate_token(&token, wrong_secret);
        assert!(result.is_err());
    }
}
