use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    middleware,
    routing::{delete, post},
    Json, Router,
};
use serde::Serialize;

use crate::auth::auth_middleware;
use crate::binance::{BinanceClient, NewOrderResponse};
use crate::config::Config;
use crate::trading::{CreateGridRequest, ModifyOrderRequest};

pub fn grid_routes() -> Router<Config> {
    Router::new()
        .route("/create", post(create_grid_pair))
        .route("/modify", post(modify_order))
        .route("/:order_id", delete(cancel_order))
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
pub struct GridPairResponse {
    buy_order: NewOrderResponse,
    sell_order: NewOrderResponse,
    estimated_profit_usd: f64,
    estimated_profit_percent: f64,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

/// Create a new grid pair (BUY + SELL orders)
async fn create_grid_pair(
    State(config): State<Config>,
    headers: HeaderMap,
    Json(request): Json<CreateGridRequest>,
) -> Result<Json<GridPairResponse>, (StatusCode, Json<ErrorResponse>)> {
    // Validate request
    if request.buy_price >= request.sell_price {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Buy price must be less than sell price".to_string(),
            }),
        ));
    }

    if request.amount_usd < 1.0 {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Minimum amount is $1".to_string(),
            }),
        ));
    }

    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let (buy_order, sell_order) = client
        .create_grid_pair(request.buy_price, request.sell_price, request.amount_usd)
        .await
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: e.to_string(),
                }),
            )
        })?;

    // Calculate estimated profit
    let quantity = BinanceClient::calculate_quantity(request.amount_usd, request.buy_price);
    let profit_usd = (request.sell_price - request.buy_price) * quantity;
    let profit_percent = (request.sell_price - request.buy_price) / request.buy_price * 100.0;

    tracing::info!(
        "Created grid pair: BUY @ {} / SELL @ {} (profit: ${:.2})",
        request.buy_price,
        request.sell_price,
        profit_usd
    );

    Ok(Json(GridPairResponse {
        buy_order,
        sell_order,
        estimated_profit_usd: profit_usd,
        estimated_profit_percent: profit_percent,
    }))
}

#[derive(Serialize)]
pub struct ModifyResponse {
    new_order: NewOrderResponse,
}

/// Modify an existing order (cancel + recreate at new price)
async fn modify_order(
    State(config): State<Config>,
    headers: HeaderMap,
    Json(request): Json<ModifyOrderRequest>,
) -> Result<Json<ModifyResponse>, (StatusCode, Json<ErrorResponse>)> {
    let use_production = use_production_from_headers(&headers);
    let client = BinanceClient::for_environment(&config, use_production).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    // First get the existing order to know its side and quantity
    let orders = client.get_open_orders().await.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    let existing_order = orders.iter().find(|o| o.order_id == request.order_id).ok_or((
        StatusCode::NOT_FOUND,
        Json(ErrorResponse {
            error: "Order not found".to_string(),
        }),
    ))?;

    let side = &existing_order.side;
    let quantity = existing_order.quantity_f64();

    let new_order = client
        .modify_order(request.order_id, side, request.new_price, quantity)
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
        "Modified order {}: new price {}",
        request.order_id,
        request.new_price
    );

    Ok(Json(ModifyResponse { new_order }))
}

#[derive(Serialize)]
pub struct CancelResponse {
    success: bool,
    order_id: i64,
}

/// Cancel an order
async fn cancel_order(
    State(config): State<Config>,
    headers: HeaderMap,
    Path(order_id): Path<i64>,
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
