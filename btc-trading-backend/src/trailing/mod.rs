mod monitor;

pub use monitor::TrailingMonitor;

use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Side of the order
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum OrderSide {
    Buy,
    Sell,
}

impl OrderSide {
    pub fn as_str(&self) -> &'static str {
        match self {
            OrderSide::Buy => "BUY",
            OrderSide::Sell => "SELL",
        }
    }
}

/// Represents an order with trailing enabled
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrailingOrder {
    /// Unique ID for this trailing order
    pub id: Uuid,
    /// Current Binance order ID (changes when order is modified)
    pub order_id: i64,
    /// Side: BUY or SELL
    pub side: OrderSide,
    /// Trailing percentage (e.g., 1.0 = 1%)
    pub trailing_percent: f64,
    /// Current order price on Binance
    pub current_order_price: f64,
    /// Reference price (best price seen - lowest for BUY, highest for SELL)
    pub reference_price: f64,
    /// Order quantity
    pub quantity: f64,
    /// Whether to use production API
    pub use_production: bool,
    /// Creation timestamp
    pub created_at: i64,
}

impl TrailingOrder {
    pub fn new(
        order_id: i64,
        side: OrderSide,
        trailing_percent: f64,
        current_price: f64,
        quantity: f64,
        use_production: bool,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            order_id,
            side,
            trailing_percent,
            current_order_price: current_price,
            reference_price: current_price,
            quantity,
            use_production,
            created_at: chrono::Utc::now().timestamp_millis(),
        }
    }

    /// Calculate the new order price based on reference price
    /// Returns Some(new_price) if order should be adjusted, None otherwise
    ///
    /// Note: This should be called AFTER update_reference() so reference_price
    /// reflects the best price seen (lowest for BUY, highest for SELL)
    pub fn calculate_adjustment(&self, _market_price: f64) -> Option<f64> {
        match self.side {
            OrderSide::Buy => {
                // BUY trailing: order should be at reference + trailing%
                // Reference is the lowest market price seen
                let target_price = self.reference_price * (1.0 + self.trailing_percent / 100.0);
                // Only adjust if current order is significantly higher than target (> 0.1%)
                let price_diff = (self.current_order_price - target_price) / self.current_order_price;
                if price_diff > 0.001 {
                    return Some(round_price(target_price));
                }
            }
            OrderSide::Sell => {
                // SELL trailing: order should be at reference - trailing%
                // Reference is the highest market price seen
                let target_price = self.reference_price * (1.0 - self.trailing_percent / 100.0);
                // Only adjust if current order is significantly lower than target (> 0.1%)
                let price_diff = (target_price - self.current_order_price) / self.current_order_price;
                if price_diff > 0.001 {
                    return Some(round_price(target_price));
                }
            }
        }
        None
    }

    /// Update reference price after market price change
    pub fn update_reference(&mut self, market_price: f64) {
        match self.side {
            OrderSide::Buy => {
                // For BUY, reference is the lowest price seen
                if market_price < self.reference_price {
                    self.reference_price = market_price;
                }
            }
            OrderSide::Sell => {
                // For SELL, reference is the highest price seen
                if market_price > self.reference_price {
                    self.reference_price = market_price;
                }
            }
        }
    }

    /// Update after order modification
    pub fn update_order(&mut self, new_order_id: i64, new_price: f64) {
        self.order_id = new_order_id;
        self.current_order_price = new_price;
    }
}

/// Round price to 2 decimal places (BTCUSDT standard)
fn round_price(price: f64) -> f64 {
    (price * 100.0).round() / 100.0
}

/// Response for API endpoints
#[derive(Debug, Serialize)]
pub struct TrailingOrderResponse {
    pub id: String,
    pub order_id: i64,
    pub side: String,
    pub trailing_percent: f64,
    pub current_order_price: f64,
    pub reference_price: f64,
    pub quantity: f64,
    pub created_at: i64,
}

impl From<&TrailingOrder> for TrailingOrderResponse {
    fn from(order: &TrailingOrder) -> Self {
        Self {
            id: order.id.to_string(),
            order_id: order.order_id,
            side: order.side.as_str().to_string(),
            trailing_percent: order.trailing_percent,
            current_order_price: order.current_order_price,
            reference_price: order.reference_price,
            quantity: order.quantity,
            created_at: order.created_at,
        }
    }
}
