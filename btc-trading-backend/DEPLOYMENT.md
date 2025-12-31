# BTC Trading Backend - Deployment Documentation

## Overview

A secure Rust backend proxy for Binance trading that:
- Stores Binance API keys securely on server (not on phone)
- Exposes specific trading methods to iOS app via JWT auth
- Sends push notifications when orders are filled
- Compiled Rust binary - impossible to decompile

## Current Deployment

**URL:** `https://btc-trading-backend.fly.dev`

**Platform:** Fly.io (free tier)
- Region: Singapore (sin)
- 2 machines for high availability
- 256MB RAM each
- Auto-restart enabled

**Status:** LIVE and working with Binance TESTNET

## API Endpoints

### Public
```
GET /price/current - Get current BTC price
```

### Authentication
```
POST /auth/login
Body: {
  "app_secret": "<APP_SECRET>",
  "device_id": "unique-device-id",
  "device_name": "iPhone 15"
}
Response: { "token": "jwt...", "expires_in": 900 }

POST /auth/refresh
Header: Authorization: Bearer <token>
```

### Protected (require JWT token)
```
GET  /account/balance     - Get USDT/BTC balances
GET  /account/orders      - Get open orders

POST /grid/create         - Create grid pair (buy + sell orders)
Body: {
  "buy_price": 94000.0,
  "sell_price": 96000.0,
  "amount_usd": 100.0
}

DELETE /grid/{order_id}   - Cancel order

POST /order/limit         - Create single limit order
Body: {
  "side": "BUY" or "SELL",
  "price": 94000.0,
  "quantity": 0.001
}

POST /order/market        - Create market order (immediate execution)
Body: {
  "side": "BUY" or "SELL",
  "quantity": 0.001
}

GET  /history/trades      - Get completed trades
GET  /history/profit      - Get profit summary

POST /notifications/register
Body: { "device_token": "apns-token-from-ios" }
```

## Configured Secrets

All secrets are stored securely in Fly.io (not in code):

| Secret | Description |
|--------|-------------|
| BINANCE_API_KEY | Testnet API key |
| BINANCE_SECRET_KEY | Testnet secret |
| USE_TESTNET | `true` (change to `false` for production) |
| JWT_SECRET | `afea720d4aba3a6281043b83c344947b5cee5f5ccec043057ba6518c8597b71e` |
| APP_SECRET | `ce9bad6793e53f5974710d2342c55675924f7927c4a23a069cc8f6c4d06e3e2b` |
| APNS_KEY_ID | `K3ABFWNN73` |
| APNS_TEAM_ID | `93K49S8Q8U` |
| APNS_KEY_CONTENT | Contents of AuthKey_K3ABFWNN73.p8 |
| APNS_PRODUCTION | `false` |

## Project Structure

```
btc-trading-backend/
├── Cargo.toml              # Dependencies
├── Dockerfile              # Build container
├── fly.toml                # Fly.io config
├── .env.example            # Environment template
└── src/
    ├── main.rs             # Entry point, server setup
    ├── config.rs           # Environment configuration
    ├── auth/
    │   ├── mod.rs
    │   ├── jwt.rs          # JWT token handling
    │   └── middleware.rs   # Auth middleware
    ├── binance/
    │   ├── mod.rs
    │   ├── client.rs       # Binance API client
    │   ├── signing.rs      # HMAC-SHA256 signing
    │   └── models.rs       # API response types
    ├── notifications/
    │   ├── mod.rs
    │   ├── apns.rs         # Apple Push Notifications
    │   └── monitor.rs      # Order fill monitor (every 30s)
    ├── trading/
    │   ├── mod.rs
    │   ├── grid.rs         # Grid pair logic
    │   └── profit.rs       # Profit calculations
    └── routes/
        ├── mod.rs
        ├── auth.rs         # Login/refresh endpoints
        ├── account.rs      # Balance, orders
        ├── grid.rs         # Grid trading
        ├── history.rs      # Trade history
        ├── price.rs        # Price endpoint
        └── notifications.rs # Device registration
```

## Local Files

- **APNs Key:** `~/.apns/AuthKey_K3ABFWNN73.p8`
- **SSH Key (Oracle - unused):** `~/.ssh/ssh-key-2025-12-26.key`

---

# Next Steps

## 1. Update iOS App to Use Backend

The iOS app currently talks directly to Binance. Update it to use the backend:

### Create BackendService.swift
```swift
import Foundation

class BackendService {
    static let shared = BackendService()

    private let baseURL = "https://btc-trading-backend.fly.dev"
    private let appSecret = "ce9bad6793e53f5974710d2342c55675924f7927c4a23a069cc8f6c4d06e3e2b"

    private var token: String?
    private var tokenExpiry: Date?

    // Login and get JWT token
    func login(deviceId: String, deviceName: String) async throws -> String {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "app_secret": appSecret,
            "device_id": deviceId,
            "device_name": deviceName
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)

        self.token = response.token
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expires_in))

        return response.token
    }

    // Get account balance
    func getBalance() async throws -> AccountBalance {
        let data = try await authenticatedRequest("/account/balance")
        return try JSONDecoder().decode(AccountBalance.self, from: data)
    }

    // Create grid pair
    func createGridPair(buyPrice: Double, sellPrice: Double, amountUSD: Double) async throws {
        let body: [String: Double] = [
            "buy_price": buyPrice,
            "sell_price": sellPrice,
            "amount_usd": amountUSD
        ]
        _ = try await authenticatedRequest("/grid/create", method: "POST", body: body)
    }

    // Register for push notifications
    func registerPushToken(_ token: String) async throws {
        let body = ["device_token": token]
        _ = try await authenticatedRequest("/notifications/register", method: "POST", body: body)
    }

    private func authenticatedRequest(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
        // Ensure we have a valid token
        if token == nil || tokenExpiry ?? Date() < Date() {
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            _ = try await login(deviceId: deviceId, deviceName: UIDevice.current.name)
        }

        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body as! [String: Any])
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}

struct LoginResponse: Codable {
    let token: String
    let expires_in: Int
}
```

### Update PushNotificationManager
In `AppDelegate.swift`, after getting the device token, register with backend:
```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

    Task {
        try? await BackendService.shared.registerPushToken(token)
    }
}
```

## 2. Switch to Production Binance

When ready for real trading:

```bash
# Update secrets for production
flyctl secrets set \
  BINANCE_API_KEY="your-production-api-key" \
  BINANCE_SECRET_KEY="your-production-secret-key" \
  USE_TESTNET="false" \
  APNS_PRODUCTION="true"
```

**Important:**
- Create new API keys at https://www.binance.com/en/my/settings/api-management
- Enable ONLY "Spot Trading" - disable withdrawals
- Consider IP restriction (see below)

## 3. Get Static IP for Binance Whitelist (Optional, ~$2/month)

```bash
flyctl ips allocate-v4
```

Then add this IP to Binance API key restrictions for extra security.

## 4. Monitor Logs

```bash
flyctl logs
```

## 5. Scale Up if Needed

```bash
# Increase memory
flyctl scale memory 512

# Add more machines
flyctl scale count 3
```

---

# Useful Commands

```bash
# View app status
flyctl status

# View logs
flyctl logs

# SSH into machine
flyctl ssh console

# Update secrets
flyctl secrets set KEY=value

# List secrets
flyctl secrets list

# Redeploy
flyctl deploy

# Destroy app (careful!)
flyctl apps destroy btc-trading-backend
```

---

# Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS App (BTCWidget)                      │
│  - No Binance API keys stored                               │
│  - Authenticates with backend via JWT                       │
│  - Receives push notifications for order fills              │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS
                              │ JWT Auth
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Fly.io (Singapore) - Rust Backend              │
│  URL: https://btc-trading-backend.fly.dev                   │
│                                                             │
│  - JWT validation                                           │
│  - Rate limiting                                            │
│  - Order monitoring (every 30s)                             │
│  - Push notifications via APNs                              │
│  - Binance API keys stored in secrets                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS (HMAC signed)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Binance API                             │
│  Currently: testnet.binance.vision                          │
│  Production: api.binance.com                                │
└─────────────────────────────────────────────────────────────┘
```

---

# Costs

| Item | Cost |
|------|------|
| Fly.io (current) | $0 (free tier) |
| Dedicated IPv4 (optional) | ~$2/month |
| **Total** | **$0-2/month** |

---

# Security Notes

1. **API keys** are stored as Fly.io secrets, not in code
2. **JWT tokens** expire in 15 minutes
3. **App secret** required to get JWT token (prevents unauthorized access)
4. **Rust binary** cannot be decompiled to readable code
5. **HTTPS only** - all traffic encrypted
6. **Singapore region** - outside US to work with Binance

---

# Troubleshooting

### "Service unavailable from a restricted location"
- Binance is blocking the IP. Try a different Fly.io region:
  ```bash
  # Edit fly.toml, change primary_region to: fra, ams, sin, hkg, nrt
  flyctl deploy
  ```

### Push notifications not working
- Check APNs credentials are correct
- Ensure device token is registered with backend
- Check Fly.io logs: `flyctl logs`

### JWT token expired
- iOS app should auto-refresh using `/auth/refresh`
- Or re-login with `/auth/login`

---

Last updated: December 27, 2025
