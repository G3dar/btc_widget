use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use uuid::Uuid;

use crate::binance::BinanceClient;
use crate::config::Config;
use super::{OrderSide, TrailingOrder, TrailingOrderResponse};

/// Manages trailing orders and periodically checks/adjusts them
pub struct TrailingMonitor {
    config: Config,
    /// Trailing orders indexed by their UUID
    orders: Arc<RwLock<HashMap<Uuid, TrailingOrder>>>,
}

impl TrailingMonitor {
    pub fn new(config: Config) -> Self {
        Self {
            config,
            orders: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Add a new trailing order to monitor
    pub async fn add_order(&self, order: TrailingOrder) -> Uuid {
        let id = order.id;
        let mut orders = self.orders.write().await;
        orders.insert(id, order);
        tracing::info!("Added trailing order {}", id);
        id
    }

    /// Remove a trailing order
    pub async fn remove_order(&self, id: Uuid) -> Option<TrailingOrder> {
        let mut orders = self.orders.write().await;
        let removed = orders.remove(&id);
        if removed.is_some() {
            tracing::info!("Removed trailing order {}", id);
        }
        removed
    }

    /// Remove trailing order by Binance order ID
    pub async fn remove_by_order_id(&self, order_id: i64) -> Option<TrailingOrder> {
        let mut orders = self.orders.write().await;
        let key = orders.iter()
            .find(|(_, o)| o.order_id == order_id)
            .map(|(k, _)| *k);

        if let Some(k) = key {
            let removed = orders.remove(&k);
            if removed.is_some() {
                tracing::info!("Removed trailing order for Binance order {}", order_id);
            }
            return removed;
        }
        None
    }

    /// Get all trailing orders
    pub async fn get_all_orders(&self) -> Vec<TrailingOrderResponse> {
        let orders = self.orders.read().await;
        orders.values().map(TrailingOrderResponse::from).collect()
    }

    /// Get a specific trailing order
    pub async fn get_order(&self, id: Uuid) -> Option<TrailingOrderResponse> {
        let orders = self.orders.read().await;
        orders.get(&id).map(TrailingOrderResponse::from)
    }

    /// Start the monitoring loop
    pub async fn start(self: Arc<Self>) {
        tracing::info!("Starting trailing order monitor (10s interval)");

        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(10)).await;

            let orders = self.orders.read().await;
            if orders.is_empty() {
                continue;
            }
            drop(orders);

            if let Err(e) = self.check_and_adjust().await {
                tracing::error!("Trailing monitor error: {}", e);
            }
        }
    }

    /// Check all trailing orders and adjust if needed
    async fn check_and_adjust(&self) -> Result<(), String> {
        // Get current market price (using testnet client for price - it's the same)
        let price_client = BinanceClient::new(&self.config);
        let market_price = price_client.get_price().await
            .map_err(|e| format!("Failed to get price: {}", e))?;

        tracing::debug!("Checking trailing orders at price {}", market_price);

        // Get orders that need adjustment
        let adjustments: Vec<(Uuid, f64, TrailingOrder)> = {
            let mut orders = self.orders.write().await;
            let mut adjustments = Vec::new();

            for (id, order) in orders.iter_mut() {
                // First update reference price
                order.update_reference(market_price);

                // Check if adjustment is needed
                if let Some(new_price) = order.calculate_adjustment(market_price) {
                    adjustments.push((*id, new_price, order.clone()));
                }
            }

            adjustments
        };

        // Process adjustments (outside the lock)
        for (id, new_price, order) in adjustments {
            tracing::info!(
                "Adjusting {} trailing order {} from {} to {}",
                order.side.as_str(),
                id,
                order.current_order_price,
                new_price
            );

            match self.adjust_order(&order, new_price).await {
                Ok(new_order_id) => {
                    // Update the order with new ID and price
                    let mut orders = self.orders.write().await;
                    if let Some(o) = orders.get_mut(&id) {
                        o.update_order(new_order_id, new_price);
                        tracing::info!(
                            "Successfully adjusted order {} -> {} at {}",
                            order.order_id,
                            new_order_id,
                            new_price
                        );
                    }
                }
                Err(e) => {
                    // Check if order was filled (Unknown order error)
                    if e.contains("Unknown order") || e.contains("-2011") {
                        tracing::info!(
                            "Order {} appears to be filled, removing from monitor",
                            order.order_id
                        );
                        let mut orders = self.orders.write().await;
                        orders.remove(&id);
                    } else {
                        tracing::error!("Failed to adjust order {}: {}", id, e);
                    }
                }
            }
        }

        Ok(())
    }

    /// Adjust an order to a new price
    async fn adjust_order(&self, order: &TrailingOrder, new_price: f64) -> Result<i64, String> {
        let client = BinanceClient::for_environment(&self.config, order.use_production)
            .map_err(|e| format!("Client error: {}", e))?;

        // Cancel and recreate at new price
        let new_order = client
            .modify_order(
                order.order_id,
                order.side.as_str(),
                new_price,
                order.quantity,
            )
            .await
            .map_err(|e| format!("Modify order failed: {}", e))?;

        Ok(new_order.orderId)
    }
}

/// Shared state for trailing orders
pub type SharedTrailingMonitor = Arc<TrailingMonitor>;

impl TrailingMonitor {
    /// Create from order creation request
    pub async fn add_from_request(
        &self,
        order_id: i64,
        side: &str,
        price: f64,
        quantity: f64,
        trailing_percent: f64,
        use_production: bool,
    ) -> Uuid {
        let order_side = if side.to_uppercase() == "BUY" {
            OrderSide::Buy
        } else {
            OrderSide::Sell
        };

        let order = TrailingOrder::new(
            order_id,
            order_side,
            trailing_percent,
            price,
            quantity,
            use_production,
        );

        self.add_order(order).await
    }
}
