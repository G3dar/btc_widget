use axum::{
    routing::get,
    Json, Router,
};
use serde::Serialize;

use crate::config::Config;

pub fn debug_routes() -> Router<Config> {
    Router::new()
        .route("/outbound-ip", get(get_outbound_ip))
        .route("/health", get(health_check))
}

#[derive(Serialize)]
pub struct OutboundIpResponse {
    pub outbound_ip: String,
    pub message: String,
}

#[derive(Serialize)]
pub struct HealthResponse {
    pub status: String,
}

/// Get the outbound IP that this server uses when making external requests
async fn get_outbound_ip() -> Json<OutboundIpResponse> {
    // Try multiple IP checking services
    let services = [
        "https://api.ipify.org",
        "https://ifconfig.me/ip",
        "https://icanhazip.com",
    ];

    for service in services {
        match reqwest::get(service).await {
            Ok(response) => {
                if let Ok(ip) = response.text().await {
                    let ip = ip.trim().to_string();
                    return Json(OutboundIpResponse {
                        outbound_ip: ip.clone(),
                        message: format!("This is the IP that Binance sees. Add {} to your API key whitelist.", ip),
                    });
                }
            }
            Err(_) => continue,
        }
    }

    Json(OutboundIpResponse {
        outbound_ip: "unknown".to_string(),
        message: "Could not determine outbound IP".to_string(),
    })
}

/// Simple health check
async fn health_check() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok".to_string(),
    })
}
