use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    middleware,
    routing::post,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

use crate::auth::auth_middleware;
use crate::binance::{BinanceClient, NewOrderResponse};
use crate::config::Config;
use crate::trailing::TrailingMonitor;

/// State for order routes that includes trailing monitor
#[derive(Clone)]
pub struct OrderAppState {
    pub config: Config,
    pub trailing_monitor: Arc<TrailingMonitor>,
}

pub fn order_routes(trailing_monitor: Arc<TrailingMonitor>) -> Router<Config> {
    let state = OrderAppState {
        config: Config::from_env(),
        trailing_monitor,
    };

    Router::new()
        .route("/limit", post(create_limit_order))
        .route("/market", post(create_market_order))
        .route_layer(middleware::from_fn_with_state(
            Config::from_env(),
            auth_middleware,
        ))
        .with_state(state)
}

/// Extract use_production flag from X-Use-Production header
fn use_production_from_headers(headers: &HeaderMap) -> bool {
    headers
        .get("X-Use-Production")
        .and_then(|v| v.to_str().ok())
        .map(|v| v == "true" || v == "1")
        .unwrap_or(false)
}

#[derive(Deserialize)]
pub struct CreateLimitOrderRequest {
    pub side: String,      // "BUY" or "SELL"
    pub price: f64,
    pub quantity: f64,
    /// Optional trailing percentage (e.g., 1.0 = 1%)
    pub trailing_percent: Option<f64>,
}

#[derive(Deserialize)]
pub struct CreateMarketOrderRequest {
    pub side: String,      // "BUY" or "SELL"
    pub quantity: f64,
}

// Note: Just return NewOrderResponse directly to maintain consistent JSON format
// NewOrderResponse uses camelCase (orderId, clientOrderId, etc) to match Binance API

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

/// Create a single limit order with optional trailing
async fn create_limit_order(
    State(state): State<OrderAppState>,
    headers: HeaderMap,
    Json(request): Json<CreateLimitOrderRequest>,
) -> Result<Json<NewOrderResponse>, (StatusCode, Json<ErrorResponse>)> {
    // Validate side
    let side = request.side.to_uppercase();
    if side != "BUY" && side != "SELL" {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Side must be BUY or SELL".to_string(),
            }),
        ));
    }

    // Validate price
    if request.price <= 0.0 {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Price must be positive".to_string(),
            }),
        ));
    }

    // Validate quantity
    if request.quantity <= 0.0 {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Quantity must be positive".to_string(),
            }),
        ));
    }

    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&state.config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let order = client
        .create_limit_order(&side, request.price, request.quantity)
        .await
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: e.to_string(),
                }),
            )
        })?;

    // If trailing_percent is specified, add to trailing monitor
    if let Some(trailing_percent) = request.trailing_percent {
        if trailing_percent > 0.0 {
            let trailing_id = state.trailing_monitor.add_from_request(
                order.orderId,
                &side,
                request.price,
                request.quantity,
                trailing_percent,
                use_production,
            ).await;

            tracing::info!(
                "Created {} limit order @ {} qty {} with {}% trailing ({})",
                side,
                request.price,
                request.quantity,
                trailing_percent,
                trailing_id
            );
        } else {
            tracing::info!(
                "Created {} limit order @ {} qty {}",
                side,
                request.price,
                request.quantity
            );
        }
    } else {
        tracing::info!(
            "Created {} limit order @ {} qty {}",
            side,
            request.price,
            request.quantity
        );
    }

    Ok(Json(order))
}

/// Create a market order (immediate execution at current price)
async fn create_market_order(
    State(state): State<OrderAppState>,
    headers: HeaderMap,
    Json(request): Json<CreateMarketOrderRequest>,
) -> Result<Json<NewOrderResponse>, (StatusCode, Json<ErrorResponse>)> {
    // Validate side
    let side = request.side.to_uppercase();
    if side != "BUY" && side != "SELL" {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Side must be BUY or SELL".to_string(),
            }),
        ));
    }

    // Validate quantity
    if request.quantity <= 0.0 {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Quantity must be positive".to_string(),
            }),
        ));
    }

    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&state.config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let order = client
        .create_market_order(&side, request.quantity)
        .await
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: e.to_string(),
                }),
            )
        })?;

    tracing::info!(
        "Created {} market order qty {}",
        side,
        request.quantity
    );

    Ok(Json(order))
}
