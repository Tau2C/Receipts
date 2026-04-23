pub mod models;

use anyhow::Result;
use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use log::{debug, error, trace};
use openidconnect::{
    core::{CoreAuthenticationFlow, CoreClient, CoreProviderMetadata},
    AuthorizationCode, ClientId, ClientSecret, CsrfToken, IssuerUrl, Nonce, OAuth2TokenResponse,
    PkceCodeChallenge, PkceCodeVerifier, RedirectUrl, Scope,
};
use reqwest::Client;
use serde::Deserialize;

use crate::api::{
    card::{Card, CardProvider},
    receipts,
    retailers::{
        biedronka::AuthUrl,
        lidl::models::{Ticket, TicketDetails, TicketPageTicket, TicketsPage},
        FetchError,
    },
};

#[frb(opaque)]
#[derive(Debug)]
pub struct LidlClient {
    http_client: Client,
    access_token: Option<String>,
    refresh_token: Option<String>,
    last_fetch: Option<DateTime<Utc>>,
}

impl LidlClient {
    const CLIENT_ID: &str = "LidlPlusNativeClient";
    const CLIENT_SECRET: &str = "secret";
    const OPENIDCONNECT_CONFIG_URL: &str = "https://accounts.lidl.com";
    const CALLBACK_URL: &str = "com.lidlplus.app://callback";
    const SCOPES: &str = "openid profile offline_access lpprofile lpapis";

    const COUNTRY: &str = "PL";

    #[frb(sync)]
    pub fn new(last_fetch: Option<DateTime<Utc>>) -> Self {
        log::debug!("Lidl::new");
        Self {
            http_client: Client::new(),
            access_token: None,
            refresh_token: None,
            last_fetch,
        }
    }

    #[frb(sync, getter)]
    pub fn get_callback_url() -> String {
        log::debug!("Lidl::get_callback_url");
        Self::CALLBACK_URL.to_owned()
    }

    #[frb(sync)]
    pub fn from_token(refresh_token: String, last_fetch: Option<DateTime<Utc>>) -> Result<Self> {
        log::debug!("Lidl::from_token");
        Ok(Self {
            http_client: Client::new(),
            access_token: None,
            refresh_token: Some(refresh_token),
            last_fetch,
        })
    }

    pub async fn get_authentication_url(&self) -> Result<AuthUrl> {
        log::debug!("Lidl::get_authentication_url");
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

        let mut client = client.authorize_url(
            CoreAuthenticationFlow::AuthorizationCode,
            CsrfToken::new_random,
            Nonce::new_random,
        );

        for scope in Self::SCOPES.split(' ') {
            client = client.add_scope(Scope::new(scope.to_string()));
        }

        client = client.add_extra_param("Country", Self::COUNTRY);
        // client = client.add_extra_param("force", "true");

        let (auth_url, csrf_token, _nonce) = client.set_pkce_challenge(pkce_challenge).url();

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
        log::debug!("Lidl::exchange_code_for_token");
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

        let token_response = match client.exchange_code(AuthorizationCode::new(code)) {
            Ok(builder) => builder,
            Err(e) => {
                error!("Failed to prepare token exchange request: {}", e);
                return Err(e.into());
            }
        }
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
        log::debug!("Lidl::refresh_token");
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

        let token_response = match client
            .exchange_refresh_token(&openidconnect::RefreshToken::new(refresh_token.to_string()))
        {
            Ok(builder) => builder,
            Err(e) => {
                error!("Failed to prepare token refresh request: {}", e);
                return Err(e.into());
            }
        }
        .request_async(&self.http_client)
        .await?;

        self.access_token = Some(token_response.access_token().secret().to_string());
        if let Some(rt) = token_response.refresh_token() {
            self.refresh_token = Some(rt.secret().to_string());
        }

        Ok(())
    }

    pub async fn check_access_token(&mut self) -> Result<String> {
        log::debug!("Lidl::check_access_token");
        #[derive(Debug, Deserialize)]
        #[allow(unused)]
        struct Claims {
            nbf: i64,
            exp: i64,
            iss: String,
            aud: serde_json::Value,
            client_id: String,
            sub: String,
            auth_time: i64,
            idp: String,
            legal_terms: String,
            name: String,
            given_name: String,
            family_name: String,
            middle_name: String,
            birthdate: String,
            birthday: String,
            gender: String,
            address_zipcode: String,
            address_country: String,
            email: String,
            email_verified: String,
            phone_number: String,
            phone_prefix_number: String,
            registration_date: String,
            #[serde(rename = "registrationDate")]
            registration_date1: String,
            sid: Option<String>,
            iat: i64,
            scope: serde_json::Value,
            amr: serde_json::Value,
        }

        if let Some(token) = self.access_token.as_ref() {
            let claims = match jsonwebtoken::dangerous::insecure_decode::<Claims>(token) {
                Ok(c) => c,
                Err(e) => {
                    let msg = format!("Failed to decode JWT token claims: {:?}", e);
                    error!("{}", msg);
                    return Err(anyhow::anyhow!(msg));
                }
            };
            if claims.claims.exp > Utc::now().timestamp() {
                return Ok(token.clone());
            }
        }

        if self.refresh_token.is_some() {
            self.refresh_token().await?;
            match self.access_token.as_ref() {
                Some(access_token) => Ok(access_token.clone()),
                None => {
                    let msg = format!("Failed to get refreshed access token");
                    error!("{}", msg);
                    return Err(anyhow::anyhow!(msg));
                }
            }
        } else {
            Err(anyhow::anyhow!("Not logged in"))
        }
    }

    #[frb(ignore)]
    pub async fn tickets(&mut self, page: u8) -> Result<TicketsPage> {
        log::debug!("Lidl::tickets, page: {}", page);
        let token = self.check_access_token().await?;

        let url = format!(
            "https://tickets.lidlplus.com/api/v2/{}/tickets?pageNumber={}",
            Self::COUNTRY,
            page
        );

        let response = self.http_client.get(url).bearer_auth(token).send().await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!(
                "Failed to fetch ticketPage: {}",
                response.status()
            ));
        }

        let ticket_result = response.json::<TicketsPage>().await;
        match ticket_result {
            Ok(receipt) => Ok(receipt),
            Err(e) => {
                log::error!("Failed to parse ticketPage JSON: {:?}", e);
                Err(e.into())
            }
        }
    }

    #[frb(ignore)]
    pub async fn ticket(&mut self, ticket: TicketPageTicket) -> Result<Ticket> {
        debug!("Lidl::ticket started for id: {}", &ticket.id);
        let token = self.check_access_token().await?;
        trace!("Lidl::ticket obtained access token");

        let url = format!(
            "https://tickets.lidlplus.com/api/v3/{}/tickets/{}",
            Self::COUNTRY,
            &ticket.id
        );
        trace!("Lidl::ticket constructed URL: {}", url);

        let response = self
            .http_client
            .get(url)
            .header("Accept-Language", Self::COUNTRY)
            .bearer_auth(token)
            .send()
            .await;
        trace!("Lidl::ticket received HTTP response");

        let response = match response {
            Ok(r) => r,
            Err(e) => {
                let msg = format!(
                    "Failed to get response for ticket id: {} : {}",
                    &ticket.id, e
                );
                error!("{}", msg);
                trace!("Lidl::ticket encountered error in HTTP response: {}", e);
                return Err(anyhow::anyhow!(msg));
            }
        };
        trace!("Lidl::ticket response status: {}", response.status());

        if !response.status().is_success() {
            let msg = format!("Failed to fetch TicketDetails: {}", response.status());
            error!("{}", msg);
            trace!("Lidl::ticket non-success status: {}", response.status());
            return Err(anyhow::anyhow!(msg));
        }

        let ticket_details_result = response.json::<TicketDetails>().await;
        trace!("Lidl::ticket parsed ticket details result");
        let ticket_details = match ticket_details_result {
            Ok(details) => details,
            Err(e) => {
                log::error!("Failed to parse TicketDetails JSON: {:?}", e);
                trace!(
                    "Lidl::ticket encountered error parsing TicketDetails JSON: {}",
                    e
                );
                return Err(e.into());
            }
        };
        trace!("Lidl::ticket successfully obtained ticket details");

        Ok(Ticket::new(ticket, ticket_details))
    }

    #[frb(ignore)]
    pub async fn fetch_all_tickets(&mut self, date: DateTime<Utc>) -> Result<Vec<Ticket>> {
        log::debug!("Lidl::fetch_all_transactions, date: {}", date);
        let mut receipts = Vec::new();
        let mut page = 1;

        'main: loop {
            let paged_transactions = self.tickets(page).await?;

            for tx in paged_transactions.tickets {
                let tx_date = match DateTime::parse_from_rfc3339(&tx.date) {
                    Ok(date) => date,
                    Err(e) => {
                        error!("Error parsing date from receipt: '{}' : {}", &tx.date, e);
                        return Err(e.into());
                    }
                };
                if date > tx_date.to_utc() {
                    trace!("receipts date break, got {}", receipts.len());
                    break 'main;
                }

                let id = tx.id.clone();
                debug!("Processing transaction: {}", id);
                let transaction = self.ticket(tx).await?;
                trace!("Got ticket w ID {}", id);
                receipts.push(transaction);
                trace!("Added ticket({}) to vec", id);

                trace!("receipts.len got = {}", receipts.len());
            }

            page += 1;
            if paged_transactions.page as u32 * paged_transactions.size as u32
                > paged_transactions.total_count
            {
                trace!(
                    "receipts end break, got {} expected {}",
                    receipts.len(),
                    paged_transactions.total_count
                );
                break;
            }
        }
        Ok(receipts)
    }

    #[frb(sync)]
    pub fn get_refresh_token(&self) -> Option<String> {
        log::debug!("Lidl::get_refresh_token");
        self.refresh_token.clone()
    }
}

impl crate::api::retailers::ReceiptProvider for LidlClient {
    async fn fetch_receipts(&mut self) -> Result<Vec<receipts::Receipt>> {
        log::debug!("Lidl::fetch_receipts");
        self.fetch_receipts_after(DateTime::from(std::time::UNIX_EPOCH))
            .await
    }

    async fn fetch_receipts_after(
        &mut self,
        date: DateTime<Utc>,
    ) -> Result<Vec<receipts::Receipt>> {
        log::debug!("Lidl::fetch_receipts_after, date: {}", date);
        let tickets = match self.fetch_all_tickets(date).await {
            Ok(tickets) => tickets,
            Err(e) => {
                let msg = format!("Lidl::fetch_receipts_after failed: {}", e);
                error!("{}", msg);
                return Err(anyhow::anyhow!(msg));
            }
        };

        trace!("tickets.len got = {}", tickets.len());

        let receipts = tickets
            .into_iter()
            .filter_map(|t| t.try_into().ok())
            .collect::<Vec<_>>();
        trace!("receipts.len got = {}", receipts.len());
        Ok(receipts)
    }

    #[frb(sync, getter)]
    fn get_last_fetch(&self) -> Option<DateTime<Utc>> {
        log::debug!("Lidl::get_last_fetch");
        self.last_fetch
    }

    #[frb(sync, setter)]
    fn set_last_fetch(&mut self, value: Option<DateTime<Utc>>) {
        log::debug!("Lidl::set_last_fetch");
        self.last_fetch = value
    }
}

impl CardProvider for LidlClient {
    async fn fetch_card(&mut self) -> Result<Card, FetchError> {
        log::debug!("Lidl::fetch_card");
        todo!()
    }
}
