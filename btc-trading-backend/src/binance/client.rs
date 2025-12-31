use super::models::*;
use super::signing::build_signed_query;
use crate::config::{BinanceCredentials, Config};
use reqwest::Client;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum BinanceError {
    #[error("Network error: {0}")]
    Network(#[from] reqwest::Error),

    #[error("API error: {code} - {message}")]
    Api { code: i32, message: String },

    #[error("Parse error: {0}")]
    Parse(String),

    #[error("Production keys not configured")]
    ProductionNotConfigured,
}

pub struct BinanceClient {
    client: Client,
    base_url: String,
    api_key: String,
    secret_key: String,
}

impl BinanceClient {
    /// Create a client from credentials
    pub fn from_credentials(credentials: &BinanceCredentials) -> Self {
        Self {
            client: Client::new(),
            base_url: credentials.base_url.to_string(),
            api_key: credentials.api_key.clone(),
            secret_key: credentials.secret_key.clone(),
        }
    }

    /// Create a client for the specified environment
    pub fn for_environment(config: &Config, use_production: bool) -> Result<Self, BinanceError> {
        let credentials = config
            .get_credentials(use_production)
            .ok_or(BinanceError::ProductionNotConfigured)?;
        Ok(Self::from_credentials(&credentials))
    }

    /// Create a testnet client (legacy support)
    pub fn new(config: &Config) -> Self {
        let credentials = config.get_credentials(false).unwrap();
        Self::from_credentials(&credentials)
    }

    // ========================================================================
    // Public Endpoints (no signature required)
    // ========================================================================

    /// Get current price for BTCUSDT
    pub async fn get_price(&self) -> Result<f64, BinanceError> {
        let url = format!("{}/api/v3/ticker/price?symbol=BTCUSDT", self.base_url);

        let response = self.client.get(&url).send().await?;

        if !response.status().is_success() {
            let error: super::models::BinanceError = response.json().await?;
            return Err(BinanceError::Api {
                code: error.code,
                message: error.msg,
            });
        }

        let ticker: TickerPrice = response.json().await?;
        Ok(ticker.price_f64())
    }

    // ========================================================================
    // Private Endpoints (signature required)
    // ========================================================================

    /// Get account balance
    pub async fn get_account(&self) -> Result<AccountInfo, BinanceError> {
        let query = build_signed_query(&[], &self.secret_key);
        let url = format!("{}/api/v3/account?{}", self.base_url, query);

        let response = self
            .client
            .get(&url)
            .header("X-MBX-APIKEY", &self.api_key)
            .send()
            .await?;

        self.handle_response(response).await
    }

    /// Get open orders for BTCUSDT
    pub async fn get_open_orders(&self) -> Result<Vec<Order>, BinanceError> {
        let query = build_signed_query(&[("symbol", "BTCUSDT")], &self.secret_key);
        let url = format!("{}/api/v3/openOrders?{}", self.base_url, query);

        let response = self
            .client
            .get(&url)
            .header("X-MBX-APIKEY", &self.api_key)
            .send()
            .await?;

        self.handle_response(response).await
    }

    /// Get trade history
    pub async fn get_trades(&self, limit: u32) -> Result<Vec<Trade>, BinanceError> {
        let limit_str = limit.to_string();
        let query = build_signed_query(
            &[("symbol", "BTCUSDT"), ("limit", &limit_str)],
            &self.secret_key,
        );
        let url = format!("{}/api/v3/myTrades?{}", self.base_url, query);

        let response = self
            .client
            .get(&url)
            .header("X-MBX-APIKEY", &self.api_key)
            .send()
            .await?;

        self.handle_response(response).await
    }

    /// Create a limit order
    pub async fn create_limit_order(
        &self,
        side: &str,
        price: f64,
        quantity: f64,
    ) -> Result<NewOrderResponse, BinanceError> {
        let price_str = format!("{:.2}", price);
        let qty_str = format!("{:.5}", quantity);

        let params = [
            ("symbol", "BTCUSDT"),
            ("side", side),
            ("type", "LIMIT"),
            ("timeInForce", "GTC"),
            ("price", &price_str),
            ("quantity", &qty_str),
        ];

        let query = build_signed_query(&params, &self.secret_key);
        let url = format!("{}/api/v3/order", self.base_url);

        let response = self
            .client
            .post(&url)
            .header("X-MBX-APIKEY", &self.api_key)
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body(query)
            .send()
            .await?;

        self.handle_response(response).await
    }

    /// Create a market order (immediate execution at current price)
    pub async fn create_market_order(
        &self,
        side: &str,
        quantity: f64,
    ) -> Result<NewOrderResponse, BinanceError> {
        let qty_str = format!("{:.5}", quantity);

        let params = [
            ("symbol", "BTCUSDT"),
            ("side", side),
            ("type", "MARKET"),
            ("quantity", &qty_str),
        ];

        let query = build_signed_query(&params, &self.secret_key);
        let url = format!("{}/api/v3/order", self.base_url);

        let response = self
            .client
            .post(&url)
            .header("X-MBX-APIKEY", &self.api_key)
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body(query)
            .send()
            .await?;

        self.handle_response(response).await
    }

    /// Cancel an order
    pub async fn cancel_order(&self, order_id: i64) -> Result<CancelOrderResponse, BinanceError> {
        let order_id_str = order_id.to_string();
        let query = build_signed_query(
            &[("symbol", "BTCUSDT"), ("orderId", &order_id_str)],
            &self.secret_key,
        );
        let url = format!("{}/api/v3/order?{}", self.base_url, query);

        let response = self
            .client
            .delete(&url)
            .header("X-MBX-APIKEY", &self.api_key)
            .send()
            .await?;

        self.handle_response(response).await
    }

    // ========================================================================
    // Helper Methods
    // ========================================================================

    async fn handle_response<T: serde::de::DeserializeOwned>(
        &self,
        response: reqwest::Response,
    ) -> Result<T, BinanceError> {
        if !response.status().is_success() {
            let error_text = response.text().await.unwrap_or_default();
            if let Ok(error) = serde_json::from_str::<super::models::BinanceError>(&error_text) {
                return Err(BinanceError::Api {
                    code: error.code,
                    message: error.msg,
                });
            }
            return Err(BinanceError::Api {
                code: -1,
                message: error_text,
            });
        }

        response
            .json()
            .await
            .map_err(|e| BinanceError::Parse(e.to_string()))
    }

    /// Calculate BTC quantity from USD amount
    pub fn calculate_quantity(usd_amount: f64, price: f64) -> f64 {
        if price <= 0.0 {
            return 0.0;
        }
        usd_amount / price
    }
}

// ============================================================================
// Grid Trading Helper
// ============================================================================

impl BinanceClient {
    /// Create a grid pair (BUY + SELL orders)
    pub async fn create_grid_pair(
        &self,
        buy_price: f64,
        sell_price: f64,
        amount_usd: f64,
    ) -> Result<(NewOrderResponse, NewOrderResponse), BinanceError> {
        let quantity = Self::calculate_quantity(amount_usd, buy_price);

        // Create both orders concurrently
        let (buy_result, sell_result) = tokio::join!(
            self.create_limit_order("BUY", buy_price, quantity),
            self.create_limit_order("SELL", sell_price, quantity)
        );

        Ok((buy_result?, sell_result?))
    }

    /// Modify an order (cancel and recreate at new price)
    pub async fn modify_order(
        &self,
        order_id: i64,
        side: &str,
        new_price: f64,
        quantity: f64,
    ) -> Result<NewOrderResponse, BinanceError> {
        // First cancel the existing order
        self.cancel_order(order_id).await?;

        // Create new order at the new price
        self.create_limit_order(side, new_price, quantity).await
    }
}
