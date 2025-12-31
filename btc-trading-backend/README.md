# BTC Trading Backend

Secure Rust backend for BTCWidget iOS app. Handles all Binance API communication with proper security.

## Features

- **Secure API Keys**: Binance credentials stored on server, not on phone
- **JWT Authentication**: Device-bound tokens with 15-minute expiry
- **Grid Trading**: Create/modify/cancel buy+sell order pairs
- **Profit Tracking**: Track completed trades and calculate profits
- **Rate Limiting**: Built-in protection against abuse

## API Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/auth/login` | POST | No | Register device, get JWT token |
| `/auth/refresh` | POST | No | Refresh JWT token |
| `/account/balance` | GET | Yes | Get USDT/BTC balances |
| `/account/orders` | GET | Yes | Get open orders (as grid pairs) |
| `/grid/create` | POST | Yes | Create grid pair (BUY+SELL) |
| `/grid/modify` | POST | Yes | Modify existing order |
| `/grid/{id}` | DELETE | Yes | Cancel order |
| `/history/trades` | GET | Yes | Get completed trades |
| `/history/profit` | GET | Yes | Get profit summary |
| `/price/current` | GET | No | Get current BTC price |

## Oracle Cloud Setup (Free Tier)

### Step 1: Create Oracle Cloud Account

1. Go to [cloud.oracle.com](https://cloud.oracle.com)
2. Click "Start for Free"
3. Complete registration (credit card required but won't be charged)
4. Wait for account activation (~30 minutes)

### Step 2: Create VM Instance

1. Go to **Compute > Instances > Create Instance**
2. Configure:
   - **Name**: `btc-backend`
   - **Image**: Ubuntu 22.04 (or Oracle Linux)
   - **Shape**: Ampere (ARM) - `VM.Standard.A1.Flex`
   - **OCPU**: 4, **Memory**: 24 GB (all free tier)
   - **Networking**: Create new VCN with public subnet
   - **Add SSH keys**: Upload your public key or generate new

3. Click **Create**

### Step 3: Configure Firewall

1. Go to **Networking > Virtual Cloud Networks > your VCN**
2. Click on your **Subnet > Security List**
3. Add **Ingress Rules**:

| Source CIDR | Protocol | Destination Port | Description |
|-------------|----------|------------------|-------------|
| 0.0.0.0/0 | TCP | 443 | HTTPS |
| 0.0.0.0/0 | TCP | 22 | SSH |

4. On the VM itself, also open the firewall:
```bash
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 3000 -j ACCEPT
sudo netfilter-persistent save
```

### Step 4: Note Your Public IP

1. Go to **Compute > Instances > your instance**
2. Copy the **Public IP address**
3. This is the IP you'll whitelist on Binance

### Step 5: Install Rust

SSH into your VM:
```bash
ssh ubuntu@YOUR_PUBLIC_IP
```

Install Rust:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### Step 6: Deploy the Backend

Clone/copy project to server:
```bash
mkdir -p ~/btc-backend
# Copy files via scp or git clone
```

Create `.env` file:
```bash
cd ~/btc-backend
cp .env.example .env
nano .env
# Fill in your Binance keys and secrets
```

Build and run:
```bash
cargo build --release
./target/release/btc-trading-backend
```

### Step 7: Set Up as Service (Auto-start)

Create systemd service:
```bash
sudo nano /etc/systemd/system/btc-backend.service
```

```ini
[Unit]
Description=BTC Trading Backend
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/btc-backend
ExecStart=/home/ubuntu/btc-backend/target/release/btc-trading-backend
Restart=always
RestartSec=5
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable btc-backend
sudo systemctl start btc-backend
sudo systemctl status btc-backend
```

### Step 8: Set Up HTTPS (Let's Encrypt)

Option A: Using Caddy (easiest):
```bash
sudo apt install caddy
sudo nano /etc/caddy/Caddyfile
```

```
your-domain.com {
    reverse_proxy localhost:3000
}
```

Option B: Using nginx + certbot:
```bash
sudo apt install nginx certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### Step 9: Whitelist IP on Binance

1. Go to Binance > API Management
2. Edit your API key
3. Add your Oracle VM's public IP to whitelist
4. Enable only **Spot Trading** (no withdrawals!)

## Security Checklist

- [ ] API keys in `.env`, not in code
- [ ] `.env` has restricted permissions (`chmod 600 .env`)
- [ ] Firewall allows only ports 443 and 22
- [ ] Binance API has IP whitelist enabled
- [ ] Binance API has withdrawal disabled
- [ ] JWT secret is 32+ random characters
- [ ] App secret is 32+ random characters
- [ ] HTTPS enabled with valid certificate

## Generate Secrets

```bash
# Generate JWT secret
openssl rand -hex 32

# Generate App secret
openssl rand -hex 32
```

## Testing

Test the API locally:
```bash
# Get price (no auth)
curl http://localhost:3000/price/current

# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"device_id":"test123","device_name":"Test Device","app_secret":"YOUR_APP_SECRET"}'

# Get balance (with auth)
curl http://localhost:3000/account/balance \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Updating iOS App

Update `BTCWidget` to use this backend instead of direct Binance calls:

1. Remove Binance API keys from Keychain
2. Add backend URL to app config
3. Implement JWT auth flow
4. Call backend endpoints instead of Binance

## License

Private - All rights reserved
