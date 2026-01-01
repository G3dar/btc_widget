use axum::{
    extract::State,
    http::StatusCode,
    middleware,
    routing::{delete, get},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use uuid::Uuid;

use crate::auth::auth_middleware;
use crate::config::Config;
use crate::trailing::{TrailingMonitor, TrailingOrderResponse};

/// App state that includes trailing monitor
#[derive(Clone)]
pub struct TrailingAppState {
    pub config: Config,
    pub monitor: Arc<TrailingMonitor>,
}

pub fn trailing_routes(monitor: Arc<TrailingMonitor>) -> Router<Config> {
    let state = TrailingAppState {
        config: Config::from_env(),
        monitor,
    };

    Router::new()
        .route("/orders", get(get_trailing_orders))
        .route("/order/:id", delete(delete_trailing_order))
        .route_layer(middleware::from_fn_with_state(
            Config::from_env(),
            auth_middleware,
        ))
        .with_state(state)
}

#[derive(Serialize)]
pub struct TrailingOrdersResponse {
    orders: Vec<TrailingOrderResponse>,
    count: usize,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

#[derive(Serialize)]
pub struct DeleteResponse {
    success: bool,
    message: String,
}

/// Get all active trailing orders
async fn get_trailing_orders(
    State(state): State<TrailingAppState>,
) -> Result<Json<TrailingOrdersResponse>, (StatusCode, Json<ErrorResponse>)> {
    let orders = state.monitor.get_all_orders().await;
    let count = orders.len();

    Ok(Json(TrailingOrdersResponse { orders, count }))
}

/// Delete a trailing order (stops trailing but doesn't cancel the order)
async fn delete_trailing_order(
    State(state): State<TrailingAppState>,
    axum::extract::Path(id): axum::extract::Path<String>,
) -> Result<Json<DeleteResponse>, (StatusCode, Json<ErrorResponse>)> {
    let uuid = Uuid::parse_str(&id).map_err(|_| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Invalid UUID format".to_string(),
            }),
        )
    })?;

    match state.monitor.remove_order(uuid).await {
        Some(_) => Ok(Json(DeleteResponse {
            success: true,
            message: format!("Trailing order {} stopped", id),
        })),
        None => Err((
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                error: format!("Trailing order {} not found", id),
            }),
        )),
    }
}
