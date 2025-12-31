use crate::binance::BinanceClient;
use crate::config::Config;
use crate::notifications::ApnsClient;
use std::collections::HashSet;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;

pub struct OrderMonitor {
    config: Config,
    apns: Arc<ApnsClient>,
    known_order_ids: Arc<RwLock<HashSet<i64>>>,
    last_trade_id: Arc<RwLock<Option<i64>>>,
}

impl OrderMonitor {
    pub fn new(config: Config, apns: Arc<ApnsClient>) -> Self {
        Self {
            config,
            apns,
            known_order_ids: Arc::new(RwLock::new(HashSet::new())),
            last_trade_id: Arc::new(RwLock::new(None)),
        }
    }

    /// Start the order monitoring loop
    pub async fn start(&self) {
        tracing::info!("🔄 Starting order monitor (checking every 30 seconds)");

        // Initialize known orders
        self.initialize_known_orders().await;

        loop {
            self.check_for_fills().await;
            tokio::time::sleep(Duration::from_secs(30)).await;
        }
    }

    /// Initialize with current open orders so we don't notify on startup
    async fn initialize_known_orders(&self) {
        let client = BinanceClient::new(&self.config);

        // Get current open orders
        if let Ok(orders) = client.get_open_orders().await {
            let mut known = self.known_order_ids.write().await;
            for order in orders {
                known.insert(order.order_id);
            }
            tracing::info!("📋 Initialized with {} known orders", known.len());
        }

        // Get last trade ID
        if let Ok(trades) = client.get_trades(1).await {
            if let Some(trade) = trades.first() {
                *self.last_trade_id.write().await = Some(trade.id);
                tracing::info!("📋 Last trade ID: {}", trade.id);
            }
        }
    }

    /// Check for newly filled orders
    async fn check_for_fills(&self) {
        let client = BinanceClient::new(&self.config);

        // Get current open orders
        let current_orders = match client.get_open_orders().await {
            Ok(orders) => orders,
            Err(e) => {
                tracing::error!("Failed to get orders: {:?}", e);
                return;
            }
        };

        let current_order_ids: HashSet<i64> = current_orders.iter().map(|o| o.order_id).collect();

        // Find orders that disappeared (filled or cancelled)
        let known = self.known_order_ids.read().await;
        let missing_ids: Vec<i64> = known
            .iter()
            .filter(|id| !current_order_ids.contains(id))
            .cloned()
            .collect();
        drop(known);

        // Check recent trades to see if orders were filled
        if !missing_ids.is_empty() {
            if let Ok(trades) = client.get_trades(20).await {
                let last_id = self.last_trade_id.read().await.unwrap_or(0);

                for trade in trades.iter().filter(|t| t.id > last_id) {
                    // This is a new trade - send notification
                    if trade.is_buyer {
                        self.apns
                            .notify_buy_filled(trade.price_f64(), trade.quantity_f64())
                            .await;
                    } else {
                        // For sells, try to calculate profit
                        // (simplified - just notify without profit for now)
                        self.apns
                            .notify_sell_filled(trade.price_f64(), trade.quantity_f64(), None)
                            .await;
                    }
                }

                // Update last trade ID
                if let Some(latest) = trades.first() {
                    *self.last_trade_id.write().await = Some(latest.id);
                }
            }
        }

        // Update known orders
        let mut known = self.known_order_ids.write().await;
        *known = current_order_ids;
    }
}
