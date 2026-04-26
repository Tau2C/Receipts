pub mod models;

use self::models::{
    ErrorResponse, LoginFirstStepRequestWithCard, LoginFirstStepResponse, LoginLastStepRequest,
    LoginLastStepResponse, PagedTransactions, Transaction, TransactionDetails, UserProfileData,
    VerifyTokenResponse,
};
use super::{FetchError, ReceiptProvider};
use crate::api::card::{Card, CardProvider};
use crate::api::receipts;
use crate::api::retailers::spolem::models::{
    LoginFirstStepRequestWithPhone, TransactionWithDetails,
};
use chrono::{DateTime, Local, NaiveDateTime, Utc};
use flutter_rust_bridge::frb;
use log::debug;
use reqwest::StatusCode;
use std::str::FromStr;

const BASE_URL: &str = "https://app3.spolemznaczyrazem.pl/api/mobile";

#[frb]
pub struct SpolemClient {
    client: reqwest::Client,
    token: Option<String>,
    last_fetch: Option<DateTime<Utc>>,
}

impl SpolemClient {
    #[frb(sync)]
    pub fn new(last_fetch: Option<DateTime<Utc>>) -> Self {
        log::debug!("SpolemClient::new");
        Self {
            client: reqwest::Client::new(),
            last_fetch,
            token: None,
        }
    }

    #[frb(sync)]
    pub fn from_token(token: String, last_fetch: Option<DateTime<Utc>>) -> Self {
        log::debug!("SpolemClient::from_token");
        Self {
            client: reqwest::Client::new(),
            last_fetch,
            token: Some(token),
        }
    }

    pub async fn login_first_step_with_card(
        &self,
        card_nr: &str,
    ) -> Result<LoginFirstStepResponse, reqwest::Error> {
        log::debug!("SpolemClient::login_first_step_with_card");
        let request_body = LoginFirstStepRequestWithCard { card_nr };
        let request = self
            .client
            .post(format!("{}/auth/login-first-step", BASE_URL))
            .json(&request_body);
        let response = request.send().await;

        let response = match response {
            Ok(response) => response,
            Err(e) => {
                log::error!("Login first step request failed: {:#?}", e);
                return Err(e);
            }
        };

        let result = response.json::<LoginFirstStepResponse>().await;
        if let Err(e) = &result {
            log::error!("Failed to parse LoginFirstStepResponse JSON: {:?}", e);
        }
        result
    }

    pub async fn login_first_step_with_phone(
        &self,
        phone: &str,
    ) -> Result<LoginFirstStepResponse, reqwest::Error> {
        log::debug!("SpolemClient::login_first_step_with_phone");
        let request_body = LoginFirstStepRequestWithPhone { phone };
        let response = self
            .client
            .post(format!("{}/auth/login-first-step", BASE_URL))
            .json(&request_body)
            .send()
            .await;

        let response = match response {
            Ok(response) => response,
            Err(e) => {
                log::error!("Login first step with phone request failed: {:#?}", e);
                return Err(e);
            }
        };

        let result = response.json::<LoginFirstStepResponse>().await;
        if let Err(e) = &result {
            log::error!("Failed to parse LoginFirstStepResponse JSON: {:?}", e);
        }
        result
    }

    pub async fn login_last_step(
        &mut self,
        phone: &str,
        code: &str,
    ) -> Result<LoginLastStepResponse, reqwest::Error> {
        log::debug!("SpolemClient::login_last_step");
        let request_body = LoginLastStepRequest { phone, code };
        let response = self
            .client
            .post(format!("{}/auth/login-last-step", BASE_URL))
            .json(&request_body)
            .send()
            .await;

        let response = match response {
            Ok(response) => response,
            Err(e) => {
                log::error!("Login last step request failed: {:#?}", e);
                return Err(e);
            }
        };

        let response_result = response.json::<LoginLastStepResponse>().await;

        let response = match response_result {
            Ok(response) => response,
            Err(e) => {
                log::error!("Failed to parse LoginLastStepResponse JSON: {:?}", e);
                return Err(e);
            }
        };

        if response.success {
            self.token = Some(response.token.clone());
        }

        Ok(response)
    }

    pub async fn verify_token(&mut self) -> Result<VerifyTokenResponse, FetchError> {
        log::debug!("SpolemClient::verify_token");
        let token = self
            .token
            .as_ref()
            .ok_or_else(|| FetchError::InavlidLogin {
                file: file!().to_string(),
                line: line!(),
            })?
            .clone();
        let response = self
            .client
            .get(format!("{}/verify-token", BASE_URL))
            .bearer_auth(&token)
            .send()
            .await
            .map_err(|e| map_reqwest_error(e, file!().to_string(), line!()))?;

        let status = response.status();
        let response_text = response
            .text()
            .await
            .map_err(|e| map_reqwest_error(e, file!().to_string(), line!()))?;

        match status {
            StatusCode::OK => {
                let verify_response: VerifyTokenResponse = serde_json::from_str(&response_text)
                    .map_err(|e| {
                        log::error!("Failed to parse VerifyTokenResponse JSON: {:?}", e);
                        FetchError::ClientError {
                            file: file!().to_string(),
                            line: line!(),
                        }
                    })?;
                if verify_response.success {
                    self.token = Some(verify_response.token.clone());
                    Ok(verify_response)
                } else {
                    Err(FetchError::ClientError {
                        file: file!().to_string(),
                        line: line!(),
                    })
                }
            }
            StatusCode::BAD_REQUEST => {
                let error_body_result = serde_json::from_str::<ErrorResponse>(&response_text);
                match error_body_result {
                    Ok(error_body) => {
                        if error_body.message == "Token is already valid" {
                            Ok(VerifyTokenResponse {
                                success: true,
                                token: token,
                                shop_id: 0,
                            })
                        } else {
                            Err(FetchError::BadRequest {
                                message: error_body.message,
                                file: file!().to_string(),
                                line: line!(),
                            })
                        }
                    }
                    Err(e) => {
                        log::error!(
                            "Failed to parse ErrorResponse JSON from BAD_REQUEST: {:?}",
                            e
                        );
                        Err(FetchError::ClientError {
                            file: file!().to_string(),
                            line: line!(),
                        })
                    }
                }
            }
            _ => Err(FetchError::UnexpectedStatus {
                status,
                file: file!().to_string(),
                line: line!(),
            }),
        }
    }

    #[frb(ignore)]
    pub async fn fetch_transactions_page(
        &self,
        page: u32,
    ) -> Result<PagedTransactions, FetchError> {
        log::debug!("SpolemClient::fetch_transactions_page, page: {}", page);
        let token = self.token.as_ref().ok_or(FetchError::InavlidLogin {
            file: file!().to_string(),
            line: line!(),
        })?;
        let response = self
            .client
            .get(format!("{}/auth/transactions?page={}", BASE_URL, page))
            .bearer_auth(token)
            .send()
            .await
            .map_err(|e| map_reqwest_error(e, file!().to_string(), line!()))?;

        let response_text = response.text().await.map_err(|e| {
            log::error!("Failed to read response text: {:?}", e);
            map_reqwest_error(e, file!().to_string(), line!())
        })?;

        let paged_transactions = serde_json::from_str::<PagedTransactions>(&response_text)
            .map_err(|e| {
                log::error!(
                    "Failed to parse PagedTransactions JSON: {:?}, json: {}",
                    e,
                    response_text
                );
                FetchError::ClientError {
                    file: file!().to_string(),
                    line: line!(),
                }
            })?;

        debug!("Fetched page {}: {:#?}", page, paged_transactions.meta);

        Ok(paged_transactions)
    }

    #[frb(ignore)]
    pub async fn fetch_transaction_details(
        &self,
        transaction: &Transaction,
    ) -> Result<TransactionWithDetails, FetchError> {
        log::debug!(
            "SpolemClient::fetch_transaction_details, id: {}",
            transaction.transaction_id
        );
        let token = self.token.as_ref().ok_or(FetchError::InavlidLogin {
            file: file!().to_string(),
            line: line!(),
        })?;
        let details = self
            .client
            .get(format!(
                "{}/auth/transactions/{}",
                BASE_URL, transaction.transaction_id
            ))
            .bearer_auth(token)
            .send()
            .await
            .map_err(|e| map_reqwest_error(e, file!().to_string(), line!()))?
            .json::<TransactionDetails>()
            .await
            .map_err(|e| {
                log::error!("Failed to parse TransactionDetails JSON: {:?}", e);
                map_reqwest_error(e, file!().to_string(), line!())
            })?;

        debug!(
            "Transaction details for {}: {:#?}",
            transaction.transaction_id, details
        );

        let twd = transaction.clone().with_details(details);

        debug!("Transaction with details: {:#?}", twd);

        Ok(twd)
    }

    #[frb(ignore)]
    pub async fn fetch_all_receipts(
        &self,
        date: DateTime<Utc>,
    ) -> Result<Vec<TransactionWithDetails>, FetchError> {
        log::debug!("SpolemClient::fetch_all_receipts, date: {}", date);
        let mut receipts = Vec::new();
        let mut page = 1;
        'main: loop {
            let paged_transactions = self.fetch_transactions_page(page).await?;

            for tx in paged_transactions.data {
                if let Ok(tx_date) = NaiveDateTime::parse_from_str(&tx.date, "%Y-%m-%d %H:%M:%S") {
                    if date
                        > tx_date
                            .and_local_timezone(Local)
                            .earliest()
                            .unwrap()
                            .to_utc()
                    {
                        break 'main;
                    }
                    debug!("Processing transaction: {}", tx.transaction_id);
                    let transaction = self.fetch_transaction_details(&tx).await?;
                    receipts.push(transaction);
                }
            }

            if paged_transactions.links.next.is_none() {
                break;
            }
            page += 1;
        }
        Ok(receipts)
    }
}

fn map_reqwest_error(error: reqwest::Error, file: String, line: u32) -> FetchError {
    log::debug!("map_reqwest_error, file: {}, line: {}", file, line);
    log::error!("{} {}", file, line);
    if error.is_status() {
        match error.status() {
            Some(reqwest::StatusCode::UNAUTHORIZED) | Some(reqwest::StatusCode::FORBIDDEN) => {
                FetchError::InavlidLogin { file, line }
            }
            Some(s) if s.is_server_error() => FetchError::ServerError { file, line },
            Some(s) => FetchError::UnexpectedStatus {
                status: s,
                file: file.to_string(),
                line,
            },
            _ => FetchError::ClientError { file, line },
        }
    } else {
        FetchError::ClientError { file, line }
    }
}

impl ReceiptProvider for SpolemClient {
    async fn fetch_receipts(&mut self) -> anyhow::Result<Vec<receipts::Receipt>> {
        log::debug!("SpolemClient::fetch_receipts");
        self.fetch_receipts_after(DateTime::from_timestamp_secs(0).unwrap())
            .await
    }

    async fn fetch_receipts_after(
        &mut self,
        date: DateTime<Utc>,
    ) -> anyhow::Result<Vec<receipts::Receipt>> {
        log::debug!("SpolemClient::fetch_receipts_after, date: {}", date);
        Ok(self
            .fetch_all_receipts(date)
            .await?
            .into_iter()
            .map(|t| {
                receipts::Receipt::new(
                    None,
                    receipts::ReceiptStore::Spolem(t.receipt_id.clone()),
                    NaiveDateTime::parse_from_str(&t.date, "%Y-%m-%d %H:%M:%S")
                        .map_err(|e| {
                            log::error!("Failed to parse date: {} | {}", e, t.date);
                            FetchError::ClientError {
                                file: file!().to_string(),
                                line: line!(),
                            }
                        })
                        .and_then(|dt| {
                            dt.and_local_timezone(Local).earliest().ok_or_else(|| {
                                log::error!("Failed timezone conversion: {}", t.date);
                                FetchError::ClientError {
                                    file: file!().to_string(),
                                    line: line!(),
                                }
                            })
                        })
                        .map(|dt| dt.to_utc())
                        .unwrap(),
                    t.details
                        .into_iter()
                        .map(|mut i| {
                            let loc = i.name.rfind(',');
                            let (ean, name) = match loc {
                                Some(loc) => {
                                    let (mut ean, name) = (i.name.split_off(loc), i.name);
                                    ean.remove(0);
                                    log::debug!("EAN: {:?}, name: {}", ean, name);
                                    (Some(ean), name)
                                }
                                None => (None, i.name),
                            };

                            let (ean, id) = if let Some(ean) = ean {
                                if ean.len() == 13 {
                                    (Some(ean), None)
                                } else {
                                    (None, Some(ean))
                                }
                            } else {
                                (None, None)
                            };

                            receipts::ReceiptItem::new(
                                id,
                                ean,
                                name,
                                (i.total_value
                                    / f64::from_str(&i.amount)
                                        .map_err(|e| {
                                            log::error!(
                                                "Failed to parse amount as f64: {} | {}",
                                                e,
                                                i.amount
                                            );
                                            FetchError::ClientError {
                                                file: file!().to_string(),
                                                line: line!(),
                                            }
                                        })
                                        .unwrap()) as f32,
                                f32::from_str(&i.amount)
                                    .map_err(|e| {
                                        log::error!(
                                            "Failed to parse amount as f32: {} | {}",
                                            e,
                                            i.amount
                                        );
                                        FetchError::ClientError {
                                            file: file!().to_string(),
                                            line: line!(),
                                        }
                                    })
                                    .unwrap(),
                                Vec::new(),
                                i.total_value as f32,
                                None,
                                None,
                            )
                        })
                        .collect(),
                    f32::from_str(&t.total)
                        .map_err(|e| {
                            log::error!("Failed to parse total as f32: {} | {}", e, t.total);
                            FetchError::ClientError {
                                file: file!().to_string(),
                                line: line!(),
                            }
                        })
                        .unwrap(),
                    Vec::new(),
                    Vec::new(),
                    0.0,
                    Vec::new(),
                )
            })
            .collect())
    }

    #[frb(sync, getter)]
    fn get_last_fetch(&self) -> Option<DateTime<Utc>> {
        log::debug!("SpolemClient::get_last_fetch");
        self.last_fetch
    }

    #[frb(sync, setter)]
    fn set_last_fetch(&mut self, value: Option<DateTime<Utc>>) {
        log::debug!("SpolemClient::set_last_fetch");
        self.last_fetch = value
    }
}

impl CardProvider for SpolemClient {
    async fn fetch_card(&mut self) -> Result<Card, FetchError> {
        log::debug!("SpolemClient::fetch_card");
        let token = self.token.as_ref().ok_or(FetchError::InavlidLogin {
            file: file!().to_string(),
            line: line!(),
        })?;

        let profile_data = self
            .client
            .get(format!("{}/auth/edit", BASE_URL))
            .bearer_auth(token)
            .send()
            .await
            .map_err(|e| map_reqwest_error(e, file!().to_string(), line!()))?
            .json::<UserProfileData>()
            .await
            .map_err(|e| {
                log::error!("Failed to parse UserProfileData JSON: {:?}", e);
                map_reqwest_error(e, file!().to_string(), line!())
            })?;

        let user_profile = profile_data.data;
        let first_card = user_profile.ecards.first().or(user_profile.cards.first());

        if let Some(api_card) = first_card {
            Ok(Card {
                id: None,
                name: "Społem".to_string(),
                number: api_card.number.to_string(),
                enabled: api_card.enabled,
            })
        } else {
            Err(FetchError::ClientError {
                file: file!().to_string(),
                line: line!(),
            })
        }
    }
}
