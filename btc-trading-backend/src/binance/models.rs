use serde::{Deserialize, Serialize};

// ============================================================================
// Account Models
// ============================================================================

#[derive(Debug, Deserialize)]
pub struct AccountInfo {
    pub balances: Vec<Balance>,
    #[serde(rename = "canTrade")]
    pub can_trade: bool,
    #[serde(rename = "canWithdraw")]
    pub can_withdraw: bool,
    #[serde(rename = "canDeposit")]
    pub can_deposit: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Balance {
    pub asset: String,
    pub free: String,
    pub locked: String,
}

impl Balance {
    pub fn free_f64(&self) -> f64 {
        self.free.parse().unwrap_or(0.0)
    }

    pub fn locked_f64(&self) -> f64 {
        self.locked.parse().unwrap_or(0.0)
    }

    pub fn total(&self) -> f64 {
        self.free_f64() + self.locked_f64()
    }
}

// ============================================================================
// Order Models
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Order {
    #[serde(rename = "orderId")]
    pub order_id: i64,
    pub symbol: String,
    pub side: String,
    #[serde(rename = "type")]
    pub order_type: String,
    pub price: String,
    #[serde(rename = "origQty")]
    pub orig_qty: String,
    #[serde(rename = "executedQty")]
    pub executed_qty: String,
    pub status: String,
    pub time: i64,
}

impl Order {
    pub fn price_f64(&self) -> f64 {
        self.price.parse().unwrap_or(0.0)
    }

    pub fn quantity_f64(&self) -> f64 {
        self.orig_qty.parse().unwrap_or(0.0)
    }

    pub fn is_buy(&self) -> bool {
        self.side == "BUY"
    }

    pub fn usd_value(&self) -> f64 {
        self.price_f64() * self.quantity_f64()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewOrderResponse {
    pub symbol: String,
    #[serde(rename = "orderId")]
    pub order_id: i64,
    #[serde(rename = "clientOrderId")]
    pub client_order_id: String,
    #[serde(rename = "transactTime")]
    pub transact_time: i64,
    pub price: String,
    #[serde(rename = "origQty")]
    pub orig_qty: String,
    #[serde(rename = "executedQty")]
    pub executed_qty: String,
    pub status: String,
    #[serde(rename = "type")]
    pub order_type: String,
    pub side: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CancelOrderResponse {
    pub symbol: String,
    #[serde(rename = "orderId")]
    pub order_id: i64,
    pub status: String,
}

// ============================================================================
// Trade History Models
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Trade {
    pub id: i64,
    #[serde(rename = "orderId")]
    pub order_id: i64,
    pub symbol: String,
    pub price: String,
    pub qty: String,
    #[serde(rename = "quoteQty")]
    pub quote_qty: String,
    pub commission: String,
    #[serde(rename = "commissionAsset")]
    pub commission_asset: String,
    pub time: i64,
    #[serde(rename = "isBuyer")]
    pub is_buyer: bool,
    #[serde(rename = "isMaker")]
    pub is_maker: bool,
}

impl Trade {
    pub fn price_f64(&self) -> f64 {
        self.price.parse().unwrap_or(0.0)
    }

    pub fn quantity_f64(&self) -> f64 {
        self.qty.parse().unwrap_or(0.0)
    }
}

// ============================================================================
// Price Models
// ============================================================================

#[derive(Debug, Serialize, Deserialize)]
pub struct TickerPrice {
    pub symbol: String,
    pub price: String,
}

impl TickerPrice {
    pub fn price_f64(&self) -> f64 {
        self.price.parse().unwrap_or(0.0)
    }
}

// ============================================================================
// API Error Response
// ============================================================================

#[derive(Debug, Deserialize)]
pub struct BinanceError {
    pub code: i32,
    pub msg: String,
}
