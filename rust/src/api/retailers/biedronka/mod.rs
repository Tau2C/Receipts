pub mod models;

use anyhow::Result;
use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use log::debug;
use openidconnect::core::{CoreAuthenticationFlow, CoreClient, CoreProviderMetadata};
use openidconnect::{
    AuthorizationCode, ClientId, ClientSecret, CsrfToken, IssuerUrl, Nonce, OAuth2TokenResponse,
    PkceCodeChallenge, PkceCodeVerifier, RedirectUrl, Scope,
};
use reqwest::{Client, Url};
use serde::Deserialize;

use crate::api::retailers::biedronka::models::{Receipt, TransactionsPage};
use crate::api::{
    card::{Card, CardProvider},
    receipts::{self},
    retailers::FetchError,
};

#[frb]
#[derive(Debug)]
pub struct AuthUrl {
    pub url: Url,
    pub pkce_verifier_secret: String,
    pub csrf_token_secret: String,
}

#[frb(opaque)]
#[derive(Debug)]
pub struct BiedronkaClient {
    http_client: Client,
    access_token: Option<String>,
    refresh_token: Option<String>,
    last_fetch: Option<DateTime<Utc>>,
}

impl BiedronkaClient {
    const CLIENT_ID: &str = "cma20";
    const CLIENT_SECRET: &str = "";
    const OPENIDCONNECT_CONFIG_URL: &str = "https://konto.biedronka.pl/realms/loyalty";
    const CALLBACK_URL: &str = "app://cma20.biedronka.pl";

    #[frb(sync)]
    pub fn new(last_fetch: Option<DateTime<Utc>>) -> Self {
        log::debug!("Biedronka::new");
        Self {
            http_client: Client::new(),
            access_token: None,
            refresh_token: None,
            last_fetch,
        }
    }

    #[frb(sync, getter)]
    pub fn get_callback_url() -> String {
        log::debug!("Biedronka::get_callback_url");
        Self::CALLBACK_URL.to_owned()
    }

    #[frb(sync)]
    pub fn from_token(refresh_token: String, last_fetch: Option<DateTime<Utc>>) -> Result<Self> {
        log::debug!("Biedronka::from_token");
        Ok(Self {
            http_client: Client::new(),
            access_token: None,
            refresh_token: Some(refresh_token),
            last_fetch,
        })
    }

    pub async fn get_authentication_url(&self) -> Result<AuthUrl> {
        log::debug!("Biedronka::get_authentication_url");
        let provider_metadata = CoreProviderMetadata::discover_async(
            IssuerUrl::new(Self::OPENIDCONNECT_CONFIG_URL.to_string())?,
            &self.http_client,
        )
        .await?;

        let client = CoreClient::from_provider_metadata(
            provider_metadata,
            ClientId::new(Self::CLIENT_ID.to_string()),
            Some(ClientSecret::new(Self::CLIENT_SECRET.to_string())),
        )
        .set_redirect_uri(RedirectUrl::new(Self::CALLBACK_URL.to_string())?);

        let (pkce_challenge, pkce_verifier) = PkceCodeChallenge::new_random_sha256();

        let (auth_url, csrf_token, _nonce) = client
            .authorize_url(
                CoreAuthenticationFlow::AuthorizationCode,
                CsrfToken::new_random,
                Nonce::new_random,
            )
            .add_scope(Scope::new("openid".to_string()))
            .set_pkce_challenge(pkce_challenge)
            .url();

        Ok(AuthUrl {
            url: auth_url,
            pkce_verifier_secret: pkce_verifier.secret().to_string(),
            csrf_token_secret: csrf_token.secret().to_string(),
        })
    }

    pub async fn exchange_code_for_token(
        &mut self,
        code: String,
        pkce_verifier_secret: String,
        state_from_redirect: String,
        csrf_secret: String,
    ) -> Result<()> {
        log::debug!("Biedronka::exchange_code_for_token");
        if state_from_redirect != csrf_secret {
            return Err(anyhow::anyhow!("CSRF token mismatch"));
        }
        let provider_metadata = CoreProviderMetadata::discover_async(
            IssuerUrl::new(Self::OPENIDCONNECT_CONFIG_URL.to_string())?,
            &self.http_client,
        )
        .await?;

        let client = CoreClient::from_provider_metadata(
            provider_metadata,
            ClientId::new(Self::CLIENT_ID.to_string()),
            Some(ClientSecret::new(Self::CLIENT_SECRET.to_string())),
        )
        .set_redirect_uri(RedirectUrl::new(Self::CALLBACK_URL.to_string())?);

        let pkce_verifier = PkceCodeVerifier::new(pkce_verifier_secret);

        let token_response = client
            .exchange_code(AuthorizationCode::new(code))
            .unwrap()
            .set_pkce_verifier(pkce_verifier)
            .request_async(&self.http_client)
            .await?;

        self.access_token = Some(token_response.access_token().secret().to_string());
        self.refresh_token = token_response
            .refresh_token()
            .map(|rt| rt.secret().to_string());

        Ok(())
    }

    async fn refresh_token(&mut self) -> Result<()> {
        log::debug!("Biedronka::refresh_token");
        let refresh_token = self
            .refresh_token
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("Not logged in"))?;

        let provider_metadata = CoreProviderMetadata::discover_async(
            IssuerUrl::new(Self::OPENIDCONNECT_CONFIG_URL.to_string())?,
            &self.http_client,
        )
        .await?;

        let client = CoreClient::from_provider_metadata(
            provider_metadata,
            ClientId::new(Self::CLIENT_ID.to_string()),
            Some(ClientSecret::new(Self::CLIENT_SECRET.to_string())),
        )
        .set_redirect_uri(RedirectUrl::new(Self::CALLBACK_URL.to_string())?);

        let token_response = client
            .exchange_refresh_token(&openidconnect::RefreshToken::new(refresh_token.to_string()))
            .unwrap()
            .request_async(&self.http_client)
            .await?;

        self.access_token = Some(token_response.access_token().secret().to_string());
        if let Some(rt) = token_response.refresh_token() {
            self.refresh_token = Some(rt.secret().to_string());
        }

        Ok(())
    }

    pub async fn check_access_token(&mut self) -> Result<String> {
        log::debug!("Biedronka::check_access_token");
        #[derive(Debug, Deserialize)]
        #[allow(unused)]
        struct Claims {
            exp: i64,
            iat: i64,
            auth_time: i64,
            jti: String,
            iss: String,
            aud: String,
            sub: String,
            typ: String,
            azp: String,
            sid: String,
            realm_access: serde_json::Value,
            resource_access: serde_json::Value,
            scope: String,
            email_verified: bool,
            gender: String,
            loyalty_card_number: String,
            name: String,
            preferred_username: String,
            given_name: String,
            email: String,
            loyalty_customer_id: String,
        }

        if let Some(token) = self.access_token.as_ref() {
            let claims = match jsonwebtoken::dangerous::insecure_decode::<Claims>(token) {
                Ok(c) => c,
                Err(e) => {
                    log::error!("Failed to decode JWT token claims: {:?}", e);
                    return Err(e.into());
                }
            };
            if claims.claims.exp > Utc::now().timestamp() {
                return Ok(token.clone());
            }
        }

        if self.refresh_token.is_some() {
            self.refresh_token().await?;
            Ok(self.access_token.clone().unwrap())
        } else {
            Err(anyhow::anyhow!("Not logged in"))
        }
    }

    #[frb(ignore)]
    pub async fn archived_transactions(&mut self, page: u8) -> Result<TransactionsPage> {
        log::debug!("Biedronka::archived_transactions, page: {}", page);
        let token = self.check_access_token().await?;

        let url = format!(
            "https://api.prod.biedronka.cloud/api/v6/transactions/archived/?page={}",
            page
        );

        let response = self.http_client.get(url).bearer_auth(token).send().await?;

        if response.status().is_success() {
            let transactions_page_result = response.json::<TransactionsPage>().await;
            match transactions_page_result {
                Ok(transactions_page) => Ok(transactions_page),
                Err(e) => {
                    log::error!("Failed to parse transactions page JSON: {:?}", e);
                    Err(e.into())
                }
            }
        } else {
            Err(anyhow::anyhow!(
                "Failed to fetch archived transactions: {}",
                response.status()
            ))
        }
    }

    #[frb(ignore)]
    pub async fn transactions(&mut self, page: u8) -> Result<TransactionsPage> {
        log::debug!("Biedronka::transactions, page: {}", page);
        let token = self.check_access_token().await?;

        let url = format!(
            "https://api.prod.biedronka.cloud/api/v6/transactions/?page={}",
            page
        );

        let response = self.http_client.get(url).bearer_auth(token).send().await?;

        if response.status().is_success() {
            let transactions_page_result = response.json::<TransactionsPage>().await;
            match transactions_page_result {
                Ok(transactions_page) => Ok(transactions_page),
                Err(e) => {
                    log::error!("Failed to parse transactions page JSON: {:?}", e);
                    Err(e.into())
                }
            }
        } else {
            Err(anyhow::anyhow!(
                "Failed to fetch transactions: {}",
                response.status()
            ))
        }
    }

    #[frb(ignore)]
    pub async fn transaction(&mut self, id: &str) -> Result<Receipt> {
        log::debug!("Biedronka::transaction, id: {}", id);
        let token = self.check_access_token().await?;

        let url = format!(
            "https://api.prod.biedronka.cloud/api/v6/transactions/{}/",
            id
        );

        let response = self.http_client.get(url).bearer_auth(token).send().await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!(
                "Failed to fetch receipt: {}",
                response.status()
            ));
        }

        let receipt_result = response.json::<Receipt>().await;
        match receipt_result {
            Ok(receipt) => Ok(receipt),
            Err(e) => {
                log::error!("Failed to parse receipt JSON: {:?}", e);
                Err(e.into())
            }
        }
    }

    #[frb(ignore)]
    pub async fn fetch_all_transactions(&mut self, date: DateTime<Utc>) -> Result<Vec<Receipt>> {
        log::debug!("Biedronka::fetch_all_transactions, date: {}", date);
        let mut receipts = Vec::new();
        let mut page = 1;
        let mut archived = false;
        'main: loop {
            let paged_transactions = if archived {
                self.archived_transactions(page).await?
            } else {
                self.transactions(page).await?
            };

            for tx in paged_transactions.transactions {
                if date > DateTime::parse_from_rfc3339(&tx.date).unwrap().to_utc() {
                    break 'main;
                }
                debug!("Processing transaction: {}", tx.id);
                let transaction = self.transaction(&tx.id).await?;
                receipts.push(transaction);
            }

            page += 1;
            if paged_transactions.next_page.is_none() {
                if archived {
                    break;
                } else {
                    archived = true;
                    page = 1;
                }
            }
        }
        Ok(receipts)
    }

    #[frb(sync)]
    pub fn get_refresh_token(&self) -> Option<String> {
        log::debug!("Biedronka::get_refresh_token");
        self.refresh_token.clone()
    }
}

impl crate::api::retailers::ReceiptProvider for BiedronkaClient {
    async fn fetch_receipts(&mut self) -> Result<Vec<receipts::Receipt>> {
        log::debug!("Biedronka::fetch_receipts");
        self.fetch_receipts_after(DateTime::from_timestamp_secs(0).unwrap())
            .await
    }

    async fn fetch_receipts_after(
        &mut self,
        date: DateTime<Utc>,
    ) -> Result<Vec<receipts::Receipt>> {
        log::debug!("Biedronka::fetch_receipts_after, date: {}", date);
        Ok(self
            .fetch_all_transactions(date)
            .await?
            .into_iter()
            .map(|t| t.into())
            .collect())
    }

    #[frb(sync, getter)]
    fn get_last_fetch(&self) -> Option<DateTime<Utc>> {
        log::debug!("Biedronka::get_last_fetch");
        self.last_fetch
    }

    #[frb(sync, setter)]
    fn set_last_fetch(&mut self, value: Option<DateTime<Utc>>) {
        log::debug!("Biedronka::set_last_fetch");
        self.last_fetch = value
    }
}

impl CardProvider for BiedronkaClient {
    async fn fetch_card(&mut self) -> Result<Card, FetchError> {
        log::debug!("Biedronka::fetch_card");
        todo!()
    }
}
