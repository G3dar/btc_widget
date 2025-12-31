use axum::{
    extract::State,
    http::StatusCode,
    middleware,
    routing::post,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

use crate::auth::auth_middleware;
use crate::config::Config;
use crate::notifications::ApnsClient;

pub fn notification_routes(apns: Arc<ApnsClient>) -> Router<Config> {
    Router::new()
        .route("/register", post(register_token))
        .route("/unregister", post(unregister_token))
        .route("/test", post(test_notification))
        .layer(axum::Extension(apns))
        .route_layer(middleware::from_fn_with_state(
            Config::from_env(),
            auth_middleware,
        ))
}

#[derive(Deserialize)]
pub struct RegisterTokenRequest {
    device_token: String,
    platform: String, // "ios" or "android"
}

#[derive(Serialize)]
pub struct RegisterResponse {
    success: bool,
    message: String,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

/// Register device token for push notifications
async fn register_token(
    axum::Extension(apns): axum::Extension<Arc<ApnsClient>>,
    Json(request): Json<RegisterTokenRequest>,
) -> Result<Json<RegisterResponse>, (StatusCode, Json<ErrorResponse>)> {
    if request.platform != "ios" {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Only iOS is supported".to_string(),
            }),
        ));
    }

    apns.register_token(request.device_token).await;

    Ok(Json(RegisterResponse {
        success: true,
        message: "Device registered for notifications".to_string(),
    }))
}

#[derive(Deserialize)]
pub struct UnregisterTokenRequest {
    device_token: String,
}

/// Unregister device token
async fn unregister_token(
    axum::Extension(apns): axum::Extension<Arc<ApnsClient>>,
    Json(request): Json<UnregisterTokenRequest>,
) -> Json<RegisterResponse> {
    apns.unregister_token(&request.device_token).await;

    Json(RegisterResponse {
        success: true,
        message: "Device unregistered".to_string(),
    })
}

/// Send a test notification
async fn test_notification(
    axum::Extension(apns): axum::Extension<Arc<ApnsClient>>,
) -> Result<Json<RegisterResponse>, (StatusCode, Json<ErrorResponse>)> {
    apns.send_notification(
        "🧪 Test Notification",
        "Push notifications are working!",
        None,
    )
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    Ok(Json(RegisterResponse {
        success: true,
        message: "Test notification sent".to_string(),
    }))
}
