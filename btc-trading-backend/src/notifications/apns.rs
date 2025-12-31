use a2::{
    Client, ClientConfig, DefaultNotificationBuilder, Endpoint, NotificationBuilder, NotificationOptions,
};
use std::fs::File;
use std::io::Cursor;
use std::sync::Arc;
use tokio::sync::RwLock;

pub struct ApnsClient {
    client: Client,
    device_tokens: Arc<RwLock<Vec<String>>>,
}

impl ApnsClient {
    /// Create new APNs client from .p8 key file
    pub async fn new(
        key_path: &str,
        key_id: &str,
        team_id: &str,
        is_production: bool,
    ) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let mut key_file = File::open(key_path)?;
        let endpoint = if is_production {
            Endpoint::Production
        } else {
            Endpoint::Sandbox
        };
        let config = ClientConfig::new(endpoint);
        let client = Client::token(&mut key_file, key_id, team_id, config)?;

        Ok(Self {
            client,
            device_tokens: Arc::new(RwLock::new(Vec::new())),
        })
    }

    /// Create new APNs client from key content string (for cloud deployment)
    pub async fn from_key_content(
        key_content: &str,
        key_id: &str,
        team_id: &str,
        is_production: bool,
    ) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let mut cursor = Cursor::new(key_content.as_bytes());
        let endpoint = if is_production {
            Endpoint::Production
        } else {
            Endpoint::Sandbox
        };
        let config = ClientConfig::new(endpoint);
        let client = Client::token(&mut cursor, key_id, team_id, config)?;

        Ok(Self {
            client,
            device_tokens: Arc::new(RwLock::new(Vec::new())),
        })
    }

    /// Register a device token
    pub async fn register_token(&self, token: String) {
        let mut tokens = self.device_tokens.write().await;
        if !tokens.contains(&token) {
            tokens.push(token);
            tracing::info!("📱 Registered new device token");
        }
    }

    /// Remove a device token
    pub async fn unregister_token(&self, token: &str) {
        let mut tokens = self.device_tokens.write().await;
        tokens.retain(|t| t != token);
    }

    /// Send notification to all registered devices
    pub async fn send_notification(
        &self,
        title: &str,
        body: &str,
        data: Option<serde_json::Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let tokens = self.device_tokens.read().await;

        if tokens.is_empty() {
            tracing::warn!("No device tokens registered, skipping notification");
            return Ok(());
        }

        for token in tokens.iter() {
            let mut builder = DefaultNotificationBuilder::new()
                .set_title(title)
                .set_body(body)
                .set_sound("default")
                .set_badge(1);

            // Add custom data if provided
            if let Some(ref custom_data) = data {
                if let Some(obj) = custom_data.as_object() {
                    for (key, value) in obj {
                        if let Some(s) = value.as_str() {
                            builder = builder.set_content_available();
                        }
                    }
                }
            }

            let options = NotificationOptions {
                apns_topic: Some("com.3dar.BTCWidget"),
                ..Default::default()
            };

            let payload = builder.build(token, options);

            match self.client.send(payload).await {
                Ok(response) => {
                    tracing::info!("✅ Notification sent: {:?}", response);
                }
                Err(e) => {
                    tracing::error!("❌ Failed to send notification: {:?}", e);
                }
            }
        }

        Ok(())
    }

    /// Send buy order filled notification
    pub async fn notify_buy_filled(&self, price: f64, quantity: f64) {
        let usd_value = price * quantity;
        let title = "🟢 BUY Order Filled";
        let body = format!(
            "Bought {:.5} BTC @ ${:.0} (${:.0})",
            quantity, price, usd_value
        );

        if let Err(e) = self.send_notification(&title, &body, None).await {
            tracing::error!("Failed to send buy notification: {:?}", e);
        }
    }

    /// Send sell order filled notification with profit
    pub async fn notify_sell_filled(&self, price: f64, quantity: f64, profit: Option<f64>) {
        let usd_value = price * quantity;
        let title = "🔴 SELL Order Filled";
        let body = if let Some(p) = profit {
            format!(
                "Sold {:.5} BTC @ ${:.0} (${:.0}) +${:.2} profit!",
                quantity, price, usd_value, p
            )
        } else {
            format!("Sold {:.5} BTC @ ${:.0} (${:.0})", quantity, price, usd_value)
        };

        if let Err(e) = self.send_notification(&title, &body, None).await {
            tracing::error!("Failed to send sell notification: {:?}", e);
        }
    }
}
