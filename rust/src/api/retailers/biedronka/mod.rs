use anyhow::Result;
use chrono::{DateTime, Utc};
use fix::aliases::si::Centi;
use flutter_rust_bridge::frb;
use openidconnect::core::{CoreAuthenticationFlow, CoreClient, CoreProviderMetadata};
use openidconnect::{
    AuthorizationCode, ClientId, ClientSecret, CsrfToken, IssuerUrl, Nonce, OAuth2TokenResponse,
    PkceCodeChallenge, PkceCodeVerifier, RedirectUrl, Scope,
};
use reqwest::{Client, Url};
use serde::Deserialize;

use crate::api::receipts::TaxGroup;
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
pub struct Biedronka {
    http_client: Client,
    access_token: Option<String>,
    refresh_token: Option<String>,
    last_fetch: Option<DateTime<Utc>>,
}

impl Biedronka {
    const CLIENT_ID: &str = "cma20";
    const CLIENT_SECRET: &str = "";
    const OPENIDCONNECT_CONFIG_URL: &str =
        "https://konto.biedronka.pl/realms/loyalty/.well-known/openid-configuration";
    const CALLBACK_URL: &str = "app://cma20.biedronka.pl";

    #[frb(sync)]
    pub fn new(last_fetch: Option<DateTime<Utc>>) -> Self {
        Self {
            http_client: Client::new(),
            access_token: None,
            refresh_token: None,
            last_fetch,
        }
    }

    #[frb(sync, getter)]
    pub fn get_callback_url() -> String {
        Self::CALLBACK_URL.to_owned()
    }

    #[frb(sync)]
    pub fn from_token(refresh_token: String, last_fetch: Option<DateTime<Utc>>) -> Self {
        Self {
            http_client: Client::new(),
            access_token: None,
            refresh_token: Some(refresh_token),
            last_fetch,
        }
    }

    pub async fn get_authentication_url(&self) -> Result<AuthUrl> {
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

    pub async fn archived_transactions(&self, page: u8) -> Result<TransactionsPage> {
        let token = self
            .access_token
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("Not logged in"))?;

        let url = format!(
            "https://api.prod.biedronka.cloud/api/v6/transactions/archived/?page={}",
            page
        );

        let response = self.http_client.get(url).bearer_auth(token).send().await?;

        if response.status().is_success() {
            let transactions_page = response.json::<TransactionsPage>().await?;
            Ok(transactions_page)
        } else {
            Err(anyhow::anyhow!(
                "Failed to fetch archived transactions: {}",
                response.status()
            ))
        }
    }

    pub async fn transactions(&self, page: u8) -> Result<TransactionsPage> {
        let token = self
            .access_token
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("Not logged in"))?;

        let url = format!(
            "https://api.prod.biedronka.cloud/api/v6/transactions/?page={}",
            page
        );

        let response = self.http_client.get(url).bearer_auth(token).send().await?;

        if response.status().is_success() {
            let transactions_page = response.json::<TransactionsPage>().await?;
            Ok(transactions_page)
        } else {
            Err(anyhow::anyhow!(
                "Failed to fetch transactions: {}",
                response.status()
            ))
        }
    }

    pub async fn transaction(&self, id: &str) -> Result<Receipt> {
        let token = self
            .access_token
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("Not logged in"))?;

        let url = format!(
            "https://api.prod.biedronka.cloud/api/v6/transactions/{}/e-receipt/",
            id
        );

        let response = self
            .http_client
            .get(url)
            .bearer_auth(token)
            .header("output-format", "json")
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!(
                "Failed to fetch e-receipt: {}",
                response.status()
            ));
        }

        let receipt: Receipt = response.json().await?;

        Ok(receipt)
    }

    #[frb(sync)]
    pub fn get_refresh_token(&self) -> Option<String> {
        self.refresh_token.clone()
    }
}

impl crate::api::retailers::ReceiptProvider for Biedronka {
    async fn fetch_receipts(&mut self) -> Result<Vec<receipts::Receipt>, FetchError> {
        todo!()
    }

    async fn fetch_receipts_older_than(
        &mut self,
        date: chrono::DateTime<chrono::Utc>,
    ) -> Result<Vec<receipts::Receipt>, FetchError> {
        let r = self.fetch_receipts().await;
        if let Ok(r) = r {
            Ok(r.into_iter().filter(|r| r.issued_at() >= date).collect())
        } else {
            r
        }
    }
}

impl CardProvider for Biedronka {
    async fn fetch_card(&mut self) -> Result<Card, FetchError> {
        todo!()
    }
}

#[derive(Debug, Deserialize)]
struct Receipt {
    id: String,
    date: String,
    total_price: f32,
    store_name: String,
    receipt_num: String,
    is_e_receipt_available: bool,
    total_discount: f32,
    store_id: String,
    cash_register_id: u8,
    id_from_receipt: String,
    cashier_id: Option<String>,
    basket_id: Option<String>,
    invoice_id: Option<String>,
    total_tax: f32,
    due_change: f32,
    items: Vec<Item>,
    payments: Vec<Payment>,
    tax_summaries: Vec<TaxSummary>,
    receipt_barcode: String,
    extended_transaction_number: String,
    collected_returnable_packagings_value: f32,
    sold_returnable_packagings_value: f32,
}

#[derive(Debug, Deserialize)]
struct Item {
    position: String,
    name: String,
    quantity: f32,
    unit_price: f32,
    total_discount: f32,
    total_price_without_discount: f32,
    total_price: f32,
    ean: String,
    vat_rate: u8,
    vat_fiscal_code: String,
    measure_unit: String,
}

#[derive(Debug, Deserialize)]
struct Payment {
    payment_type: String,
    name: String,
    value: f32,
}

#[derive(Debug, Deserialize)]
struct TaxSummary {
    vat_rate: u8,
    sale_value: f32,
    tax_value: f32,
    vat_fiscal_code: String,
}

impl From<Receipt> for receipts::Receipt {
    fn from(value: Receipt) -> Self {
        Self {
            id: None,
            store: receipts::ReceiptStore::Biedronka(value.id),
            issued_at: DateTime::parse_from_rfc3339(&value.date).unwrap().to_utc(),
            items: value
                .items
                .into_iter()
                .map(|i| {
                    receipts::ReceiptItem::new(
                        Some(i.ean),
                        i.name,
                        i.unit_price,
                        i.quantity,
                        Vec::new(),
                        i.total_price,
                        Some(match i.vat_fiscal_code.as_str() {
                            "A" => TaxGroup::A,
                            "B" => TaxGroup::B,
                            "C" => TaxGroup::C,
                            "E" => TaxGroup::E,
                            _ => TaxGroup::X,
                        }),
                        Some(i.vat_rate as f32 / 100.0),
                    )
                })
                .collect(),
            total: Centi::new((value.total_price * 100.0) as u32),
            discounts: Vec::new(),
            tax_summary: Vec::new(),
            tax_total: Centi::new((value.total_tax * 100.0) as u32),
            payments: Vec::new(),
        }
    }
}

#[derive(Debug, Deserialize)]
struct TransactionsPage {
    transactions: Vec<Transaction>,
    page_number: u8,
    page_count: u8,
    previous_page: Option<u8>,
    next_page: Option<u8>,
}

#[derive(Debug, Deserialize)]
struct Transaction {
    id: String,
    date: String,
    total_price: f32,
    store_name: String,
    receipt_num: String,
    is_e_receipt_available: bool,
}
