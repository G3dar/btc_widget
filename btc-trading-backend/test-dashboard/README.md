# BTC Trading Backend Test Dashboard

A simple web interface for testing the trailing order functionality without needing to recompile the iOS widget.

## Quick Start

1. Start the backend server:
   ```bash
   cd btc-trading-backend
   cargo run
   ```

2. Open the dashboard in your browser:
   ```bash
   # Option 1: Use Python's built-in server
   cd test-dashboard
   python3 -m http.server 8080
   # Then open http://localhost:8080

   # Option 2: Open directly (some features may be limited due to CORS)
   open test-dashboard/index.html
   ```

3. Configure the dashboard:
   - Set Backend URL to `http://localhost:3000`
   - Enter the `APP_SECRET` from your `.env` file
   - Click "Authenticate"

## Features

### Status Bar
- Shows backend connection status
- Real-time BTC price updates
- Count of active trailing orders

### Create Orders
- Create limit orders with optional trailing percentage
- Supports BUY and SELL sides
- Toggle between Testnet and Production

### Trailing Orders Monitor
- View all active trailing orders
- See current price, reference price, and target price
- Stop trailing for individual orders

### Test Scenarios
1. **BUY Trailing - Price Drops**: Creates a BUY order and monitors as price drops
2. **SELL Trailing - Price Rises**: Creates a SELL order and monitors as price rises
3. **Order Analysis**: Analyzes current trailing orders for potential issues

### Debug Tools
- Fetch open orders from Binance
- Cancel orders by ID
- Check account balance
- View server outbound IP (for Binance whitelist)

## Trailing Order Logic

### BUY Trailing
- Reference price tracks the **lowest** market price seen
- Order price = reference_price * (1 + trailing%)
- When market drops, reference drops, order follows down
- When market rises from low, order stays put (eventually triggers)

### SELL Trailing
- Reference price tracks the **highest** market price seen
- Order price = reference_price * (1 - trailing%)
- When market rises, reference rises, order follows up
- When market drops from high, order stays put (eventually triggers)

## Common Issues

### Orders not adjusting
- Check that trailing_percent > 0
- Verify the backend is running (`/debug/health`)
- Check backend logs for errors

### Authentication failed
- Verify APP_SECRET matches your .env file
- Check that backend is running and accessible

### CORS errors
- Run dashboard through a local server (not file://)
- Or check that backend CORS is configured correctly
