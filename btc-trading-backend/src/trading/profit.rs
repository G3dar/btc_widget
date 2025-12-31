use crate::binance::Trade;
use serde::Serialize;

/// A completed grid pair (from trade history)
#[derive(Debug, Clone, Serialize)]
pub struct CompletedPair {
    pub buy_trade: Trade,
    pub sell_trade: Trade,
    pub quantity: f64,
    pub buy_price: f64,
    pub sell_price: f64,
    pub gross_profit_usd: f64,
    pub commission_usd: f64,
    pub net_profit_usd: f64,
    pub profit_percent: f64,
    pub completed_at: i64,
}

/// Match trades into completed pairs and calculate profit
pub fn match_completed_pairs(trades: &[Trade]) -> Vec<CompletedPair> {
    let mut buy_trades: Vec<_> = trades.iter().filter(|t| t.is_buyer).cloned().collect();
    let mut sell_trades: Vec<_> = trades.iter().filter(|t| !t.is_buyer).cloned().collect();

    // Sort by time
    buy_trades.sort_by_key(|t| t.time);
    sell_trades.sort_by_key(|t| t.time);

    let mut pairs = Vec::new();
    let mut matched_buy_ids = std::collections::HashSet::new();
    let mut matched_sell_ids = std::collections::HashSet::new();

    // Match each sell with a preceding buy of similar quantity
    for sell in &sell_trades {
        for buy in &buy_trades {
            // Skip if already matched or buy happened after sell
            if matched_buy_ids.contains(&buy.id) || buy.time >= sell.time {
                continue;
            }

            // Match by similar quantity (within 5%)
            let qty_diff = (buy.quantity_f64() - sell.quantity_f64()).abs() / buy.quantity_f64();
            if qty_diff < 0.05 {
                // Only count positive trades
                if sell.price_f64() > buy.price_f64() {
                    let quantity = buy.quantity_f64().min(sell.quantity_f64());
                    let buy_price = buy.price_f64();
                    let sell_price = sell.price_f64();

                    let gross_profit = (sell_price - buy_price) * quantity;

                    // Calculate commission (approximate to USD)
                    let buy_commission = if buy.commission_asset == "USDT" {
                        buy.commission.parse().unwrap_or(0.0)
                    } else {
                        buy.commission.parse::<f64>().unwrap_or(0.0) * buy_price
                    };
                    let sell_commission = if sell.commission_asset == "USDT" {
                        sell.commission.parse().unwrap_or(0.0)
                    } else {
                        sell.commission.parse::<f64>().unwrap_or(0.0) * sell_price
                    };
                    let total_commission = buy_commission + sell_commission;

                    let net_profit = gross_profit - total_commission;
                    let profit_percent = (sell_price - buy_price) / buy_price * 100.0;

                    pairs.push(CompletedPair {
                        buy_trade: buy.clone(),
                        sell_trade: sell.clone(),
                        quantity,
                        buy_price,
                        sell_price,
                        gross_profit_usd: gross_profit,
                        commission_usd: total_commission,
                        net_profit_usd: net_profit,
                        profit_percent,
                        completed_at: sell.time,
                    });
                }

                matched_buy_ids.insert(buy.id);
                matched_sell_ids.insert(sell.id);
                break;
            }
        }
    }

    // Sort by completion time (newest first)
    pairs.sort_by(|a, b| b.completed_at.cmp(&a.completed_at));
    pairs
}

/// Summary of all trading profits
#[derive(Debug, Serialize)]
pub struct ProfitSummary {
    pub total_trades: usize,
    pub total_gross_profit: f64,
    pub total_commission: f64,
    pub total_net_profit: f64,
    pub average_profit_percent: f64,
}

pub fn calculate_profit_summary(pairs: &[CompletedPair]) -> ProfitSummary {
    if pairs.is_empty() {
        return ProfitSummary {
            total_trades: 0,
            total_gross_profit: 0.0,
            total_commission: 0.0,
            total_net_profit: 0.0,
            average_profit_percent: 0.0,
        };
    }

    let total_gross: f64 = pairs.iter().map(|p| p.gross_profit_usd).sum();
    let total_commission: f64 = pairs.iter().map(|p| p.commission_usd).sum();
    let total_net: f64 = pairs.iter().map(|p| p.net_profit_usd).sum();
    let avg_percent: f64 = pairs.iter().map(|p| p.profit_percent).sum::<f64>() / pairs.len() as f64;

    ProfitSummary {
        total_trades: pairs.len(),
        total_gross_profit: total_gross,
        total_commission: total_commission,
        total_net_profit: total_net,
        average_profit_percent: avg_percent,
    }
}
