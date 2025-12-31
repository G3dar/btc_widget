use crate::binance::{Order, Trade};
use serde::{Deserialize, Serialize};

/// A matched grid pair (BUY + SELL orders)
#[derive(Debug, Clone, Serialize)]
pub struct GridPair {
    pub buy_order: Order,
    pub sell_order: Order,
    pub profit_usd: f64,
    pub profit_percent: f64,
}

impl GridPair {
    pub fn new(buy_order: Order, sell_order: Order) -> Self {
        let qty = buy_order.quantity_f64();
        let buy_price = buy_order.price_f64();
        let sell_price = sell_order.price_f64();

        let profit_usd = (sell_price - buy_price) * qty;
        let profit_percent = if buy_price > 0.0 {
            ((sell_price - buy_price) / buy_price) * 100.0
        } else {
            0.0
        };

        Self {
            buy_order,
            sell_order,
            profit_usd,
            profit_percent,
        }
    }
}

/// Match open orders into grid pairs
pub fn match_grid_pairs(orders: &[Order]) -> (Vec<GridPair>, Vec<Order>) {
    let buy_orders: Vec<_> = orders.iter().filter(|o| o.is_buy()).collect();
    let sell_orders: Vec<_> = orders.iter().filter(|o| !o.is_buy()).collect();

    let mut pairs = Vec::new();
    let mut matched_sell_ids = std::collections::HashSet::new();
    let mut matched_buy_ids = std::collections::HashSet::new();

    // Match by similar quantity (within 1%)
    for buy in &buy_orders {
        for sell in &sell_orders {
            if matched_sell_ids.contains(&sell.order_id) {
                continue;
            }

            let qty_diff = (buy.quantity_f64() - sell.quantity_f64()).abs() / buy.quantity_f64();
            if qty_diff < 0.01 {
                pairs.push(GridPair::new((*buy).clone(), (*sell).clone()));
                matched_buy_ids.insert(buy.order_id);
                matched_sell_ids.insert(sell.order_id);
                break;
            }
        }
    }

    // Collect unpaired orders
    let unpaired: Vec<Order> = orders
        .iter()
        .filter(|o| {
            !matched_buy_ids.contains(&o.order_id) && !matched_sell_ids.contains(&o.order_id)
        })
        .cloned()
        .collect();

    (pairs, unpaired)
}

/// Request to create a new grid pair
#[derive(Debug, Deserialize)]
pub struct CreateGridRequest {
    pub buy_price: f64,
    pub sell_price: f64,
    pub amount_usd: f64,
}

/// Request to modify an order
#[derive(Debug, Deserialize)]
pub struct ModifyOrderRequest {
    pub order_id: i64,
    pub new_price: f64,
}
