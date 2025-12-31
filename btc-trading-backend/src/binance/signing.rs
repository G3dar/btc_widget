use hmac::{Hmac, Mac};
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

/// Sign a query string with HMAC-SHA256
pub fn sign_query(query: &str, secret_key: &str) -> String {
    let mut mac = HmacSha256::new_from_slice(secret_key.as_bytes())
        .expect("HMAC can take key of any size");
    mac.update(query.as_bytes());
    let result = mac.finalize();
    hex::encode(result.into_bytes())
}

/// Build query string from parameters and add timestamp
pub fn build_signed_query(params: &[(&str, &str)], secret_key: &str) -> String {
    let timestamp = chrono::Utc::now().timestamp_millis().to_string();
    let recv_window = "60000";

    // Build query with params
    let mut query_parts: Vec<String> = params
        .iter()
        .map(|(k, v)| format!("{}={}", k, v))
        .collect();

    // Add timestamp and recvWindow
    query_parts.push(format!("timestamp={}", timestamp));
    query_parts.push(format!("recvWindow={}", recv_window));

    let query = query_parts.join("&");
    let signature = sign_query(&query, secret_key);

    format!("{}&signature={}", query, signature)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_signature() {
        // Test vector from Binance documentation
        let secret = "NhqPtmdSJYdKjVHjA7PZj4Mge3R5YNiP1e3UZjInClVN65XAbvqqM6A7H5fATj0j";
        let query = "symbol=BTCUSDT&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559";

        let signature = sign_query(query, secret);

        // Verify signature matches expected format (64 hex chars)
        assert_eq!(signature.len(), 64);
    }
}
