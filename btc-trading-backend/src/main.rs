mod auth;
mod binance;
mod config;
mod notifications;
mod routes;
mod trading;

use axum::{
    http::{HeaderValue, Method},
    Router,
};
use std::net::SocketAddr;
use std::sync::Arc;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use notifications::{ApnsClient, OrderMonitor};

#[tokio::main]
async fn main() {
    // Initialize logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "btc_trading_backend=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load configuration
    dotenvy::dotenv().ok();
    let config = config::Config::from_env();

    tracing::info!("Starting BTC Trading Backend");
    tracing::info!("Testnet keys: configured");
    tracing::info!("Production keys: {}", if config.has_production_keys() { "configured" } else { "NOT configured" });

    // Initialize APNs client - try APNS_KEY_CONTENT first (for cloud), then APNS_KEY_PATH (for local)
    let apns = if let Some(ref key_content) = config.apns_key_content {
        match ApnsClient::from_key_content(
            key_content,
            &config.apns_key_id,
            &config.apns_team_id,
            config.apns_production,
        )
        .await
        {
            Ok(client) => {
                tracing::info!("✅ APNs client initialized from key content");
                Arc::new(client)
            }
            Err(e) => {
                panic!("APNs initialization failed: {}. Check APNS_KEY_CONTENT", e);
            }
        }
    } else if let Some(ref key_path) = config.apns_key_path {
        match ApnsClient::new(
            key_path,
            &config.apns_key_id,
            &config.apns_team_id,
            config.apns_production,
        )
        .await
        {
            Ok(client) => {
                tracing::info!("✅ APNs client initialized from key file");
                Arc::new(client)
            }
            Err(e) => {
                panic!("APNs initialization failed: {}. Check APNS_KEY_PATH", e);
            }
        }
    } else {
        panic!("APNs required. Set either APNS_KEY_CONTENT or APNS_KEY_PATH");
    };

    // Start order monitor in background
    let monitor_apns = apns.clone();
    let monitor_config = config.clone();
    tokio::spawn(async move {
        let monitor = OrderMonitor::new(monitor_config, monitor_apns);
        monitor.start().await;
    });

    // Build application with routes
    let app = create_router(config.clone(), apns);

    // Start server
    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    tracing::info!("Listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

fn create_router(config: config::Config, apns: Arc<ApnsClient>) -> Router {
    // CORS configuration - restrict in production
    let cors = CorsLayer::new()
        .allow_origin(Any) // In production, restrict to your app's requests
        .allow_methods([Method::GET, Method::POST, Method::DELETE, Method::OPTIONS])
        .allow_headers(Any);

    Router::new()
        .nest("/auth", routes::auth_routes())
        .nest("/account", routes::account_routes())
        .nest("/grid", routes::grid_routes())
        .nest("/order", routes::order_routes())
        .nest("/history", routes::history_routes())
        .nest("/price", routes::price_routes())
        .nest("/notifications", routes::notification_routes(apns))
        .nest("/debug", routes::debug_routes())
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(config)
}
