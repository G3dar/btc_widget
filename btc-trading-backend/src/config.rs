use std::env;

#[derive(Clone)]
pub struct BinanceCredentials {
    pub api_key: String,
    pub secret_key: String,
    pub base_url: &'static str,
}

#[derive(Clone)]
pub struct Config {
    // Server
    pub port: u16,

    // Binance API - Testnet
    pub binance_testnet_api_key: String,
    pub binance_testnet_secret_key: String,

    // Binance API - Production
    pub binance_prod_api_key: Option<String>,
    pub binance_prod_secret_key: Option<String>,

    // JWT
    pub jwt_secret: String,
    pub jwt_expiry_minutes: i64,

    // Security
    pub app_secret: String, // Shared secret with iOS app for request signing

    // Apple Push Notifications
    pub apns_key_path: Option<String>,
    pub apns_key_content: Option<String>,
    pub apns_key_id: String,
    pub apns_team_id: String,
    pub apns_production: bool,
}

impl Config {
    pub fn from_env() -> Self {
        // Support both old single-key format and new dual-key format
        let testnet_api_key = env::var("BINANCE_TESTNET_API_KEY")
            .or_else(|_| env::var("BINANCE_API_KEY"))
            .expect("BINANCE_TESTNET_API_KEY or BINANCE_API_KEY must be set");
        let testnet_secret_key = env::var("BINANCE_TESTNET_SECRET_KEY")
            .or_else(|_| env::var("BINANCE_SECRET_KEY"))
            .expect("BINANCE_TESTNET_SECRET_KEY or BINANCE_SECRET_KEY must be set");

        Self {
            port: env::var("PORT")
                .unwrap_or_else(|_| "3000".to_string())
                .parse()
                .unwrap_or(3000),

            binance_testnet_api_key: testnet_api_key,
            binance_testnet_secret_key: testnet_secret_key,

            binance_prod_api_key: env::var("BINANCE_PROD_API_KEY").ok(),
            binance_prod_secret_key: env::var("BINANCE_PROD_SECRET_KEY").ok(),

            jwt_secret: env::var("JWT_SECRET")
                .expect("JWT_SECRET must be set"),
            jwt_expiry_minutes: env::var("JWT_EXPIRY_MINUTES")
                .unwrap_or_else(|_| "15".to_string())
                .parse()
                .unwrap_or(15),

            app_secret: env::var("APP_SECRET")
                .expect("APP_SECRET must be set"),

            apns_key_path: env::var("APNS_KEY_PATH").ok(),
            apns_key_content: env::var("APNS_KEY_CONTENT").ok(),
            apns_key_id: env::var("APNS_KEY_ID")
                .unwrap_or_else(|_| "K3ABFWNN73".to_string()),
            apns_team_id: env::var("APNS_TEAM_ID")
                .unwrap_or_else(|_| "93K49S8Q8U".to_string()),
            apns_production: env::var("APNS_PRODUCTION")
                .unwrap_or_else(|_| "false".to_string())
                .parse()
                .unwrap_or(false),
        }
    }

    /// Get credentials for the specified environment
    pub fn get_credentials(&self, use_production: bool) -> Option<BinanceCredentials> {
        if use_production {
            // Production requires both keys to be set
            match (&self.binance_prod_api_key, &self.binance_prod_secret_key) {
                (Some(api_key), Some(secret_key)) => Some(BinanceCredentials {
                    api_key: api_key.clone(),
                    secret_key: secret_key.clone(),
                    base_url: "https://api.binance.com",
                }),
                _ => None, // Production keys not configured
            }
        } else {
            Some(BinanceCredentials {
                api_key: self.binance_testnet_api_key.clone(),
                secret_key: self.binance_testnet_secret_key.clone(),
                base_url: "https://testnet.binance.vision",
            })
        }
    }

    /// Check if production keys are configured
    pub fn has_production_keys(&self) -> bool {
        self.binance_prod_api_key.is_some() && self.binance_prod_secret_key.is_some()
    }
}
