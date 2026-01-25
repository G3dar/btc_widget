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
        order_price: f64,
        market_price: f64,
        quantity: f64,
        use_production: bool,
    ) -> Self {
        // Reference price should be initialized to the current market price
        // This ensures the trailing starts from the actual market conditions
        // For BUY: reference tracks lowest price seen (start with market)
        // For SELL: reference tracks highest price seen (start with market)
        Self {
            id: Uuid::new_v4(),
            order_id,
            side,
            trailing_percent,
            current_order_price: order_price,
            reference_price: market_price,
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

#[cfg(test)]
mod tests {
    use super::*;

    fn create_buy_order(order_price: f64, market_price: f64, trailing_percent: f64) -> TrailingOrder {
        TrailingOrder::new(
            123456,
            OrderSide::Buy,
            trailing_percent,
            order_price,
            market_price,
            0.001,
            false,
        )
    }

    fn create_sell_order(order_price: f64, market_price: f64, trailing_percent: f64) -> TrailingOrder {
        TrailingOrder::new(
            123456,
            OrderSide::Sell,
            trailing_percent,
            order_price,
            market_price,
            0.001,
            false,
        )
    }

    // ==========================================================================
    // BUY ORDER TESTS
    // ==========================================================================

    #[test]
    fn test_buy_reference_updates_on_price_drop() {
        // BUY: reference should track the LOWEST price
        // Create order at 42000, market also at 42000
        let mut order = create_buy_order(42000.0, 42000.0, 1.0);

        // Price drops to 41500
        order.update_reference(41500.0);
        assert_eq!(order.reference_price, 41500.0, "Reference should update to lower price");

        // Price drops more to 41000
        order.update_reference(41000.0);
        assert_eq!(order.reference_price, 41000.0, "Reference should update to new low");
    }

    #[test]
    fn test_buy_reference_does_not_update_on_price_rise() {
        // BUY: reference should NOT update when price rises
        let mut order = create_buy_order(42000.0, 42000.0, 1.0);

        // Set a low reference first
        order.update_reference(41000.0);
        assert_eq!(order.reference_price, 41000.0);

        // Price rises - reference should stay at 41000
        order.update_reference(42000.0);
        assert_eq!(order.reference_price, 41000.0, "Reference should NOT update on price rise");

        order.update_reference(43000.0);
        assert_eq!(order.reference_price, 41000.0, "Reference should still be at low");
    }

    #[test]
    fn test_buy_order_adjusts_down_when_price_drops() {
        // BUY with 1% trailing
        // When reference drops, target drops, order should adjust DOWN
        let mut order = create_buy_order(42000.0, 42000.0, 1.0);
        // Initial: reference=42000, current_order=42000, target=42420

        // Price drops significantly
        order.update_reference(40000.0);
        // Now: reference=40000, target=40400
        // current_order_price=42000 is HIGHER than target=40400
        // diff = (42000 - 40400) / 42000 = 0.038 = 3.8% > 0.1% threshold

        let adjustment = order.calculate_adjustment(40000.0);
        assert!(adjustment.is_some(), "Should need adjustment when price drops significantly");

        let new_price = adjustment.unwrap();
        assert!((new_price - 40400.0).abs() < 1.0, "New price should be ~40400 (reference + 1%)");
    }

    #[test]
    fn test_buy_order_no_adjustment_when_already_correct() {
        // Order is at the correct price (reference + trailing%)
        let mut order = create_buy_order(40400.0, 40000.0, 1.0);
        // reference_price = 40000 (from market_price)
        // target = 40000 * 1.01 = 40400
        // current = 40400
        // diff = (40400 - 40400) / 40400 = 0

        let adjustment = order.calculate_adjustment(40000.0);
        assert!(adjustment.is_none(), "No adjustment needed when order is at correct price");
    }

    #[test]
    fn test_buy_order_no_adjustment_when_diff_below_threshold() {
        // Difference is below 0.1% threshold
        let mut order = create_buy_order(40400.0, 40000.0, 1.0);
        // target = 40000 * 1.01 = 40400
        // diff = (40400 - 40400) / 40400 = 0 < 0.001

        let adjustment = order.calculate_adjustment(40000.0);
        assert!(adjustment.is_none(), "No adjustment when diff is at threshold");
    }

    // ==========================================================================
    // SELL ORDER TESTS
    // ==========================================================================

    #[test]
    fn test_sell_reference_updates_on_price_rise() {
        // SELL: reference should track the HIGHEST price
        let mut order = create_sell_order(42000.0, 42000.0, 1.0);

        // Price rises to 43000
        order.update_reference(43000.0);
        assert_eq!(order.reference_price, 43000.0, "Reference should update to higher price");

        // Price rises more to 44000
        order.update_reference(44000.0);
        assert_eq!(order.reference_price, 44000.0, "Reference should update to new high");
    }

    #[test]
    fn test_sell_reference_does_not_update_on_price_drop() {
        // SELL: reference should NOT update when price drops
        let mut order = create_sell_order(42000.0, 42000.0, 1.0);

        // Set a high reference first
        order.update_reference(44000.0);
        assert_eq!(order.reference_price, 44000.0);

        // Price drops - reference should stay at 44000
        order.update_reference(43000.0);
        assert_eq!(order.reference_price, 44000.0, "Reference should NOT update on price drop");

        order.update_reference(41000.0);
        assert_eq!(order.reference_price, 44000.0, "Reference should still be at high");
    }

    #[test]
    fn test_sell_order_adjusts_up_when_price_rises() {
        // SELL with 1% trailing
        // When reference rises, target rises, order should adjust UP
        let mut order = create_sell_order(42000.0, 42000.0, 1.0);
        // Initial: reference=42000, current_order=42000, target=41580

        // Price rises significantly
        order.update_reference(45000.0);
        // Now: reference=45000, target=44550 (45000 - 1%)
        // current_order_price=42000 is LOWER than target=44550
        // diff = (44550 - 42000) / 42000 = 0.0607 = 6% > 0.1% threshold

        let adjustment = order.calculate_adjustment(45000.0);
        assert!(adjustment.is_some(), "Should need adjustment when price rises significantly");

        let new_price = adjustment.unwrap();
        assert!((new_price - 44550.0).abs() < 1.0, "New price should be ~44550 (reference - 1%)");
    }

    #[test]
    fn test_sell_order_no_adjustment_when_already_correct() {
        // Order is at the correct price (reference - trailing%)
        let mut order = create_sell_order(44550.0, 45000.0, 1.0);
        // reference_price = 45000 (from market_price)
        // target = 45000 * 0.99 = 44550
        // current = 44550
        // diff = (44550 - 44550) / 44550 = 0

        let adjustment = order.calculate_adjustment(45000.0);
        assert!(adjustment.is_none(), "No adjustment needed when order is at correct price");
    }

    // ==========================================================================
    // INTEGRATION SCENARIO TESTS
    // ==========================================================================

    #[test]
    fn test_buy_trailing_full_scenario() {
        // Simulate a complete BUY trailing scenario:
        // 1. Create order at market price with 1% trailing
        // 2. Price drops over several iterations
        // 3. Order should follow the price down

        let mut order = create_buy_order(42000.0, 42000.0, 1.0);
        println!("Initial: order_price={}, reference={}", order.current_order_price, order.reference_price);

        // Iteration 1: Price drops to 41500
        order.update_reference(41500.0);
        if let Some(new_price) = order.calculate_adjustment(41500.0) {
            println!("Iter 1: Adjusting order to {}", new_price);
            order.current_order_price = new_price;
        }
        assert_eq!(order.reference_price, 41500.0);

        // Iteration 2: Price drops to 41000
        order.update_reference(41000.0);
        if let Some(new_price) = order.calculate_adjustment(41000.0) {
            println!("Iter 2: Adjusting order to {}", new_price);
            order.current_order_price = new_price;
        }
        assert_eq!(order.reference_price, 41000.0);
        // target should be 41000 * 1.01 = 41410
        assert!((order.current_order_price - 41410.0).abs() < 1.0);

        // Iteration 3: Price rises to 41300 (but still above reference)
        order.update_reference(41300.0);
        assert_eq!(order.reference_price, 41000.0, "Reference should not rise");
        // No adjustment needed since we're at correct target
    }

    #[test]
    fn test_sell_trailing_full_scenario() {
        // Simulate a complete SELL trailing scenario:
        // 1. Create order at market price with 1% trailing
        // 2. Price rises over several iterations
        // 3. Order should follow the price up

        let mut order = create_sell_order(42000.0, 42000.0, 1.0);
        println!("Initial: order_price={}, reference={}", order.current_order_price, order.reference_price);

        // Iteration 1: Price rises to 43000
        order.update_reference(43000.0);
        if let Some(new_price) = order.calculate_adjustment(43000.0) {
            println!("Iter 1: Adjusting order to {}", new_price);
            order.current_order_price = new_price;
        }
        assert_eq!(order.reference_price, 43000.0);

        // Iteration 2: Price rises to 44000
        order.update_reference(44000.0);
        if let Some(new_price) = order.calculate_adjustment(44000.0) {
            println!("Iter 2: Adjusting order to {}", new_price);
            order.current_order_price = new_price;
        }
        assert_eq!(order.reference_price, 44000.0);
        // target should be 44000 * 0.99 = 43560
        assert!((order.current_order_price - 43560.0).abs() < 1.0);

        // Iteration 3: Price drops to 43500 (but still below reference high)
        order.update_reference(43500.0);
        assert_eq!(order.reference_price, 44000.0, "Reference should not drop");
    }

    // ==========================================================================
    // MARKET PRICE INITIALIZATION TESTS (NEW FIX)
    // ==========================================================================

    #[test]
    fn test_reference_initialized_to_market_price_not_order_price() {
        // This tests the FIX: reference_price should be market_price, not order_price

        // User creates BUY order at 42000, but market is at 41500
        let order = create_buy_order(42000.0, 41500.0, 1.0);

        // Reference should be market price (41500), not order price (42000)
        assert_eq!(order.reference_price, 41500.0, "Reference should be market price");
        assert_eq!(order.current_order_price, 42000.0, "Order price should be as specified");

        // Now: reference=41500, target=41915, order=42000
        // diff = (42000 - 41915) / 42000 = 0.002 > 0.001
        // Should need adjustment to bring order down to 41915
        let adjustment = order.calculate_adjustment(41500.0);
        assert!(adjustment.is_some(), "Should need adjustment when order is above target");

        let new_price = adjustment.unwrap();
        let expected_target = 41500.0 * 1.01; // 41915
        assert!((new_price - expected_target).abs() < 1.0,
            "New price should be ~41915 (market + 1%)");
    }

    #[test]
    fn test_sell_reference_initialized_to_market_price() {
        // User creates SELL order at 42000, but market is at 43000
        let order = create_sell_order(42000.0, 43000.0, 1.0);

        // Reference should be market price (43000), not order price (42000)
        assert_eq!(order.reference_price, 43000.0, "Reference should be market price");
        assert_eq!(order.current_order_price, 42000.0, "Order price should be as specified");

        // Now: reference=43000, target=42570 (43000 * 0.99), order=42000
        // diff = (42570 - 42000) / 42000 = 0.0135 > 0.001
        // Should need adjustment to bring order UP to 42570
        let adjustment = order.calculate_adjustment(43000.0);
        assert!(adjustment.is_some(), "Should need adjustment when order is below target");

        let new_price = adjustment.unwrap();
        let expected_target = 43000.0 * 0.99; // 42570
        assert!((new_price - expected_target).abs() < 1.0,
            "New price should be ~42570 (market - 1%)");
    }

    #[test]
    fn test_price_rounding() {
        assert_eq!(round_price(42369.456), 42369.46);
        assert_eq!(round_price(42369.454), 42369.45);
        assert_eq!(round_price(42369.5), 42369.5);
    }
}
