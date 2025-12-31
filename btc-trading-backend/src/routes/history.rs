use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    middleware,
    routing::get,
    Json, Router,
};
use serde::Serialize;

use crate::auth::auth_middleware;
use crate::binance::BinanceClient;
use crate::config::Config;
use crate::trading::{calculate_profit_summary, match_completed_pairs, CompletedPair, ProfitSummary};

pub fn history_routes() -> Router<Config> {
    Router::new()
        .route("/trades", get(get_trade_history))
        .route("/profit", get(get_profit_summary))
        .route_layer(middleware::from_fn_with_state(
            Config::from_env(),
            auth_middleware,
        ))
}

/// Extract use_production flag from X-Use-Production header
fn use_production_from_headers(headers: &HeaderMap) -> bool {
    headers
        .get("X-Use-Production")
        .and_then(|v| v.to_str().ok())
        .map(|v| v == "true" || v == "1")
        .unwrap_or(false)
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

#[derive(Serialize)]
pub struct TradeHistoryResponse {
    completed_pairs: Vec<CompletedPair>,
    total_net_profit: f64,
}

/// Get trade history with completed pairs
async fn get_trade_history(
    State(config): State<Config>,
    headers: HeaderMap,
) -> Result<Json<TradeHistoryResponse>, (StatusCode, Json<ErrorResponse>)> {
    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let trades = client.get_trades(100).await.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let pairs = match_completed_pairs(&trades);
    let total_profit: f64 = pairs.iter().map(|p| p.net_profit_usd).sum();

    Ok(Json(TradeHistoryResponse {
        completed_pairs: pairs,
        total_net_profit: total_profit,
    }))
}

/// Get profit summary
async fn get_profit_summary(
    State(config): State<Config>,
    headers: HeaderMap,
) -> Result<Json<ProfitSummary>, (StatusCode, Json<ErrorResponse>)> {
    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let trades = client.get_trades(100).await.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let pairs = match_completed_pairs(&trades);
    let summary = calculate_profit_summary(&pairs);

    Ok(Json(summary))
}
