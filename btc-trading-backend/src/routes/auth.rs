use axum::{
    extract::State,
    http::StatusCode,
    routing::post,
    Json, Router,
};
use serde::{Deserialize, Serialize};

use crate::auth::{create_token, validate_token};
use crate::config::Config;

pub fn auth_routes() -> Router<Config> {
    Router::new()
        .route("/login", post(login))
        .route("/refresh", post(refresh_token))
}

#[derive(Deserialize)]
pub struct LoginRequest {
    device_id: String,
    device_name: String,
    app_secret: String, // Shared secret embedded in app
}

#[derive(Serialize)]
pub struct LoginResponse {
    token: String,
    expires_in: i64, // seconds
}

#[derive(Serialize)]
pub struct ErrorResponse {
    error: String,
}

/// Login endpoint - authenticates device and returns JWT
async fn login(
    State(config): State<Config>,
    Json(request): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (StatusCode, Json<ErrorResponse>)> {
    // Verify app secret
    if request.app_secret != config.app_secret {
        tracing::warn!("Invalid app secret from device: {}", request.device_id);
        return Err((
            StatusCode::UNAUTHORIZED,
            Json(ErrorResponse {
                error: "Invalid credentials".to_string(),
            }),
        ));
    }

    // Create JWT token
    match create_token(
        &request.device_id,
        &request.device_name,
        &config.jwt_secret,
        config.jwt_expiry_minutes,
    ) {
        Ok(token) => {
            tracing::info!("Login successful for device: {}", request.device_name);
            Ok(Json(LoginResponse {
                token,
                expires_in: config.jwt_expiry_minutes * 60,
            }))
        }
        Err(e) => {
            tracing::error!("Failed to create token: {:?}", e);
            Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: "Failed to create token".to_string(),
                }),
            ))
        }
    }
}

#[derive(Deserialize)]
pub struct RefreshRequest {
    token: String,
}

/// Refresh token endpoint - exchanges valid token for a new one
async fn refresh_token(
    State(config): State<Config>,
    Json(request): Json<RefreshRequest>,
) -> Result<Json<LoginResponse>, (StatusCode, Json<ErrorResponse>)> {
    // Validate existing token
    let claims = match validate_token(&request.token, &config.jwt_secret) {
        Ok(c) => c,
        Err(_) => {
            return Err((
                StatusCode::UNAUTHORIZED,
                Json(ErrorResponse {
                    error: "Invalid token".to_string(),
                }),
            ));
        }
    };

    // Create new token
    match create_token(
        &claims.sub,
        &claims.device_name,
        &config.jwt_secret,
        config.jwt_expiry_minutes,
    ) {
        Ok(token) => Ok(Json(LoginResponse {
            token,
            expires_in: config.jwt_expiry_minutes * 60,
        })),
        Err(_) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: "Failed to refresh token".to_string(),
            }),
        )),
    }
}
