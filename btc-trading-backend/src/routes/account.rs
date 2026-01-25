use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    middleware,
    routing::get,
    Json, Router,
};
use serde::Serialize;

use crate::auth::auth_middleware;
use crate::binance::{Balance, BinanceClient, Order};
use crate::config::Config;
use crate::trading::{match_grid_pairs, GridPair};

pub fn account_routes() -> Router<Config> {
    Router::new()
        .route("/balance", get(get_balance))
        .route("/orders", get(get_orders))
        .route("/open-orders", get(get_open_orders_raw))
        .route("/cancel/:order_id", axum::routing::delete(cancel_order))
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
pub struct BalanceResponse {
    usdt: BalanceInfo,
    btc: BalanceInfo,
    btc_value_usd: f64,
    total_usd: f64,
}

#[derive(Serialize)]
pub struct BalanceInfo {
    free: f64,
    locked: f64,
    total: f64,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

/// Get account balance
async fn get_balance(
    State(config): State<Config>,
    headers: HeaderMap,
) -> Result<Json<BalanceResponse>, (StatusCode, Json<ErrorResponse>)> {
    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    // Get balance and current price concurrently
    let (account_result, price_result) = tokio::join!(client.get_account(), client.get_price());

    let account = account_result.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let btc_price = price_result.unwrap_or(0.0);

    // Find USDT and BTC balances
    let usdt = account
        .balances
        .iter()
        .find(|b| b.asset == "USDT")
        .cloned()
        .unwrap_or(Balance {
            asset: "USDT".to_string(),
            free: "0".to_string(),
            locked: "0".to_string(),
        });

    let btc = account
        .balances
        .iter()
        .find(|b| b.asset == "BTC")
        .cloned()
        .unwrap_or(Balance {
            asset: "BTC".to_string(),
            free: "0".to_string(),
            locked: "0".to_string(),
        });

    let btc_value = btc.total() * btc_price;
    let total_usd = usdt.total() + btc_value;

    Ok(Json(BalanceResponse {
        usdt: BalanceInfo {
            free: usdt.free_f64(),
            locked: usdt.locked_f64(),
            total: usdt.total(),
        },
        btc: BalanceInfo {
            free: btc.free_f64(),
            locked: btc.locked_f64(),
            total: btc.total(),
        },
        btc_value_usd: btc_value,
        total_usd,
    }))
}

#[derive(Serialize)]
pub struct OrdersResponse {
    grid_pairs: Vec<GridPair>,
    unpaired_orders: Vec<Order>,
    total_orders: usize,
}

/// Get open orders (matched into grid pairs)
async fn get_orders(
    State(config): State<Config>,
    headers: HeaderMap,
) -> Result<Json<OrdersResponse>, (StatusCode, Json<ErrorResponse>)> {
    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let orders = client.get_open_orders().await.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let (pairs, unpaired) = match_grid_pairs(&orders);

    Ok(Json(OrdersResponse {
        total_orders: orders.len(),
        grid_pairs: pairs,
        unpaired_orders: unpaired,
    }))
}

/// Get raw open orders from Binance (for debugging)
async fn get_open_orders_raw(
    State(config): State<Config>,
    headers: HeaderMap,
) -> Result<Json<Vec<Order>>, (StatusCode, Json<ErrorResponse>)> {
    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let orders = client.get_open_orders().await.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    Ok(Json(orders))
}

#[derive(Serialize)]
pub struct CancelResponse {
    success: bool,
    order_id: i64,
}

/// Cancel an order by ID
async fn cancel_order(
    State(config): State<Config>,
    headers: HeaderMap,
    axum::extract::Path(order_id): axum::extract::Path<i64>,
) -> Result<Json<CancelResponse>, (StatusCode, Json<ErrorResponse>)> {
    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    client.cancel_order(order_id).await.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    tracing::info!("Cancelled order {}", order_id);

    Ok(Json(CancelResponse {
        success: true,
        order_id,
    }))
}
