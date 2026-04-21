use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

// === Login First Step ===
#[derive(Serialize)]
#[frb(ignore)]
pub struct LoginFirstStepRequestWithCard<'a> {
    pub card_nr: &'a str,
}

#[derive(Serialize)]
#[frb(ignore)]
pub struct LoginFirstStepRequestWithPhone<'a> {
    pub phone: &'a str,
}

#[derive(Deserialize, Debug)]
#[frb(ignore)]
pub struct LoginFirstStepResponse {
    pub success: bool,
    pub message: String,
    pub action: Option<String>,
}

// === Login Last Step ===
#[derive(Serialize)]
#[frb(ignore)]
pub struct LoginLastStepRequest<'a> {
    pub phone: &'a str,
    pub code: &'a str,
}

#[derive(Deserialize, Debug)]
#[frb(ignore)]
pub struct LoginLastStepResponse {
    pub success: bool,
    pub message: Option<String>,
    pub token: String,
    pub action: Option<String>,
    pub user: User,
}

// === User and nested structs ===
#[derive(Deserialize, Debug)]
#[frb(ignore)]
pub struct User {
    pub id: i64,
    pub first_name: String,
    pub last_name: String,
    pub sex: i32,
    pub city: Option<String>,
    pub street: Option<String>,
    pub house_nr: Option<String>,
    pub local_nr: Option<String>,
    pub post_code: Option<String>,
    pub birth_date: String,
    pub email: String,
    pub shop_id: i64,
    pub register_without_card: bool,
    pub cell_phone: String,
    pub register_completed: bool,
    pub available_points: i64,
    pub approvals: Approvals,
}

#[derive(Deserialize, Debug)]
#[frb(ignore)]
pub struct Approvals {
    pub marketing_sms: i32,
    pub marketing_mail: i32,
    pub profiling: i32,
    pub rodo_consent: i32,
    pub terms_acceptance: i32,
}

// === Transactions (Receipts) ===
#[derive(Deserialize, Debug)]
#[frb(ignore)]
pub struct PagedTransactions {
    pub data: Vec<Transaction>,
    pub links: Links,
    pub meta: Meta,
}

#[derive(Deserialize, Debug, Clone)]
#[frb(ignore)]
pub struct Transaction {
    pub transaction_id: i64,
    pub card_nr: i64,
    pub date: String,
    pub value: String,
    pub receipt: String,
    pub base_points: i64,
    pub summary_points: i64,
    pub points_promotions: i64,
    pub products_amount: i64,
    pub shop: Shop,
}

impl Transaction {
    #[frb(ignore)]
    pub fn with_details(&self, details: TransactionDetails) -> TransactionWithDetails {
        TransactionWithDetails {
            transaction_id: self.transaction_id,
            receipt_id: details.receipt_id,
            card_nr: self.card_nr,
            date: self.date.clone(),
            value: self.value.clone(),
            base_points: self.base_points,
            summary_points: self.summary_points,
            points_promotions: self.points_promotions,
            products_amount: self.products_amount,
            shop: self.shop.clone(),
            details: details.details,
            total: details.total,
        }
    }
}

#[derive(Deserialize, Debug, Clone)]
#[frb(ignore)]
pub struct Shop {
    pub id: i64,
    pub name: String,
    pub label: String,
    pub city: String,
    pub street: String,
    pub post_code: String,
    pub phone: String,
    pub email: String,
    #[serde(rename = "has_program")]
    pub has_program: String,
    pub enabled: String,
    pub company_id: i64,
    pub lat: String,
    pub long: String,
    pub opening_hours: Option<OpeningHours>,
    pub regional_company: Option<RegionalCompany>,
}

#[derive(Deserialize, Debug, Clone)]
#[frb(ignore)]
pub struct OpeningHours {
    pub saturday: String,
    pub weekdays: String,
    pub trading_sunday: String,
}

#[derive(Deserialize, Debug, Clone)]
#[frb(ignore)]
pub struct RegionalCompany {
    pub id: i64,
    pub name: String,
}

#[derive(Debug, Clone)]
#[frb(ignore)]
pub struct TransactionWithDetails {
    pub transaction_id: i64,
    pub receipt_id: String,
    pub card_nr: i64,
    pub date: String,
    pub value: String,
    pub base_points: i64,
    pub summary_points: i64,
    pub points_promotions: i64,
    pub products_amount: i64,
    pub shop: Shop,
    pub details: Vec<TransactionDetailItem>,
    pub total: String,
}

#[derive(Deserialize, Debug)]
#[frb(ignore)]
pub struct Links {
    pub first: Option<String>,
    pub last: Option<String>,
    pub prev: Option<String>,
    pub next: Option<String>,
}

#[derive(Deserialize, Debug)]
#[frb(ignore)]
pub struct Meta {
    pub current_page: i64,
    pub from: Option<i64>,
    pub last_page: i64,
    pub path: String,
    pub per_page: i64,
    pub to: Option<i64>,
    pub total: i64,
}

// === Transaction Details ===
#[derive(Deserialize, Debug)]
#[frb(ignore)]
pub struct TransactionDetails {
    pub receipt_id: String,
    pub details: Vec<TransactionDetailItem>,
    pub total: String,
}

#[derive(Deserialize, Debug, Clone)]
#[frb(ignore)]
pub struct TransactionDetailItem {
    pub id: i64,
    pub name: String,
    pub total_value: f64,
    pub amount: String,
}

// === User Profile (/auth/edit) ===
#[derive(Deserialize, Debug)]
#[frb(ignore)]
pub struct UserProfileData {
    pub data: UserProfile,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
#[frb(ignore)]
pub struct UserProfile {
    pub id: i64,
    pub first_name: String,
    pub last_name: String,
    #[serde(rename = "eCards")]
    pub ecards: Vec<ApiCard>,
    pub cards: Vec<ApiCard>,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
#[frb(ignore)]
pub struct ApiCard {
    pub number: i64,
    pub enabled: bool,
}

#[derive(serde::Deserialize, Debug)]
#[frb(ignore)]
pub struct VerifyTokenResponse {
    pub success: bool,
    pub token: String,
    #[serde(rename = "shopId")]
    pub shop_id: i64,
}

#[derive(serde::Deserialize, Debug)]
#[frb(ignore)]
pub struct ErrorResponse {
    pub message: String,
}
