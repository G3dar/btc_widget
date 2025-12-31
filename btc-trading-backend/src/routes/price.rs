use axum::{
    extract::State,
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde::Serialize;

use crate::binance::BinanceClient;
use crate::config::Config;

pub fn price_routes() -> Router<Config> {
    Router::new()
        // Price endpoint is public (no auth required)
        .route("/current", get(get_current_price))
}

#[derive(Serialize)]
pub struct PriceResponse {
    symbol: String,
    price: f64,
    timestamp: i64,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

/// Get current BTC price (public endpoint)
async fn get_current_price(
    State(config): State<Config>,
) -> Result<Json<PriceResponse>, (StatusCode, Json<ErrorResponse>)> {
    let client = BinanceClient::new(&config);

    let price = client.get_price().await.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    Ok(Json(PriceResponse {
        symbol: "BTCUSDT".to_string(),
        price,
        timestamp: chrono::Utc::now().timestamp_millis(),
    }))
}
