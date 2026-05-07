use chrono::{DateTime, Utc};
use fix::aliases::si::{Centi, Milli};
use flutter_rust_bridge::frb;
use sqlx::prelude::FromRow;

#[derive(Debug, Clone, Copy)]
pub struct Date(pub DateTime<Utc>);

impl sqlx::Type<sqlx::Sqlite> for Date {
    fn type_info() -> sqlx::sqlite::SqliteTypeInfo {
        <String as sqlx::Type<sqlx::Sqlite>>::type_info()
    }
}

impl<'q> sqlx::Encode<'q, sqlx::Sqlite> for Date {
    fn encode_by_ref(
        &self,
        buf: &mut Vec<sqlx::sqlite::SqliteArgumentValue<'q>>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        let value = self.0.to_rfc3339();
        <String as sqlx::Encode<sqlx::Sqlite>>::encode(value, buf)
    }
}

impl<'r> sqlx::Decode<'r, sqlx::Sqlite> for Date {
    fn decode(value: sqlx::sqlite::SqliteValueRef<'r>) -> Result<Self, sqlx::error::BoxDynError> {
        let raw = <String as sqlx::Decode<sqlx::Sqlite>>::decode(value)?;

        let s = DateTime::parse_from_rfc3339(&raw).unwrap().to_utc();

        Ok(Date(s))
    }
}

#[derive(Debug, Clone, Copy)]
#[frb(opaque)]
pub struct Quantity(Milli<u32>);

impl From<f64> for Quantity {
    fn from(value: f64) -> Self {
        Self(Milli::new((value * 1000.0).round() as u32))
    }
}

impl From<f32> for Quantity {
    fn from(value: f32) -> Self {
        Self(Milli::new((value * 1000.0).round() as u32))
    }
}

impl From<Quantity> for f32 {
    fn from(value: Quantity) -> f32 {
        value.0.bits as f32 / 1000.0
    }
}

impl sqlx::Type<sqlx::Sqlite> for Quantity {
    fn type_info() -> sqlx::sqlite::SqliteTypeInfo {
        <u32 as sqlx::Type<sqlx::Sqlite>>::type_info()
    }
}

impl<'q> sqlx::Encode<'q, sqlx::Sqlite> for Quantity {
    fn encode(
        self,
        buf: &mut Vec<sqlx::sqlite::SqliteArgumentValue<'q>>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        let value: u32 = self.0.bits;
        <u32 as sqlx::Encode<sqlx::Sqlite>>::encode(value, buf)
    }

    fn encode_by_ref(
        &self,
        buf: &mut Vec<sqlx::sqlite::SqliteArgumentValue<'q>>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        let value: u32 = self.0.bits;
        <u32 as sqlx::Encode<sqlx::Sqlite>>::encode(value, buf)
    }
}

impl<'r> sqlx::Decode<'r, sqlx::Sqlite> for Quantity {
    fn decode(value: sqlx::sqlite::SqliteValueRef<'r>) -> Result<Self, sqlx::error::BoxDynError> {
        let raw = <u32 as sqlx::Decode<sqlx::Sqlite>>::decode(value)?;
        Ok(Quantity(Milli::new(raw)))
    }
}

#[derive(Debug, Clone, Copy)]
#[frb(opaque)]
pub struct Price(Centi<u32>);

impl<T> TryFrom<Option<T>> for Price
where
    Price: From<T>,
{
    type Error = ();

    fn try_from(value: Option<T>) -> Result<Self, Self::Error> {
        match value {
            Some(value) => Ok(value.into()),
            None => Err(()),
        }
    }
}

impl From<f64> for Price {
    fn from(value: f64) -> Self {
        Self(Centi::new((value * 100.0) as u32))
    }
}

impl From<f32> for Price {
    fn from(value: f32) -> Self {
        Self(Centi::new((value * 100.0) as u32))
    }
}

impl From<Price> for f32 {
    fn from(value: Price) -> f32 {
        value.0.bits as f32 / 100.0
    }
}

impl sqlx::Type<sqlx::Sqlite> for Price {
    fn type_info() -> sqlx::sqlite::SqliteTypeInfo {
        <u32 as sqlx::Type<sqlx::Sqlite>>::type_info()
    }
}

impl<'q> sqlx::Encode<'q, sqlx::Sqlite> for Price {
    fn encode(
        self,
        buf: &mut Vec<sqlx::sqlite::SqliteArgumentValue<'q>>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        let value: u32 = self.0.bits;
        <u32 as sqlx::Encode<sqlx::Sqlite>>::encode(value, buf)
    }

    fn encode_by_ref(
        &self,
        buf: &mut Vec<sqlx::sqlite::SqliteArgumentValue<'q>>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        let value: u32 = self.0.bits;
        <u32 as sqlx::Encode<sqlx::Sqlite>>::encode(value, buf)
    }
}

impl<'r> sqlx::Decode<'r, sqlx::Sqlite> for Price {
    fn decode(value: sqlx::sqlite::SqliteValueRef<'r>) -> Result<Self, sqlx::error::BoxDynError> {
        let raw = <u32 as sqlx::Decode<sqlx::Sqlite>>::decode(value)?;
        Ok(Price(Centi::new(raw)))
    }
}

#[frb(opaque, ignore_all)]
#[derive(Debug, Clone, FromRow)]
pub struct Receipt {
    pub id: Option<u32>,

    pub store: Store,

    pub receipt_id: Option<String>,

    pub issued_at: Date,

    pub items: Vec<ReceiptItem>,
    pub total: Price,
    pub discounts: Vec<ReceiptDiscount>,
    pub tax_summary: Vec<ReceiptTaxSummary>,
    pub tax_total: Price,

    pub payments: Vec<ReceiptPayment>,
}

impl Receipt {
    #[frb(sync)]
    pub fn new(
        id: Option<u32>,
        store: Store,
        receipt_id: Option<String>,
        issued_at: DateTime<Utc>,

        items: Vec<ReceiptItem>,
        total: Price,
        discounts: Vec<ReceiptDiscount>,
        tax_summary: Vec<ReceiptTaxSummary>,
        tax_total: Price,

        payments: Vec<ReceiptPayment>,
    ) -> Self {
        log::debug!("Receipt::new called for store: {:?}", store);

        Self {
            id,
            store,
            receipt_id,
            issued_at: Date(issued_at),
            items,
            total: total,
            discounts,
            tax_summary,
            tax_total: tax_total,
            payments,
        }
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn id(&self) -> Option<u32> {
        log::debug!("Receipt::id getter called");
        self.id
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn receipt_store(&self) -> ReceiptStore {
        log::debug!("Receipt::receipt_store getter called");
        ReceiptStore::from_store(&self.store, self.receipt_id.clone())
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn store(&self) -> Store {
        log::debug!("Receipt::store getter called");
        self.store.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn receipt_id(&self) -> Option<String> {
        log::debug!("Receipt::receipt_id getter called");
        self.receipt_id.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn issued_at(&self) -> DateTime<Utc> {
        log::debug!("Receipt::issued_at getter called");
        self.issued_at.0
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_items(&self) -> Vec<ReceiptItem> {
        log::debug!("Receipt::items getter called");
        self.items.clone()
    }

    #[frb(sync, setter)]
    #[inline]
    pub fn set_items(&mut self, value: Vec<ReceiptItem>) {
        log::debug!("Receipt::items setter called");
        self.items = value;
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn total(&self) -> f32 {
        log::debug!("Receipt::total getter called");
        self.total.into()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn discounts(&self) -> Vec<ReceiptDiscount> {
        log::debug!("Receipt::discounts getter called");
        self.discounts.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn tax_summary(&self) -> Vec<ReceiptTaxSummary> {
        log::debug!("Receipt::tax_summary getter called");
        self.tax_summary.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn tax_total(&self) -> f32 {
        log::debug!("Receipt::tax_total getter called");
        self.tax_total.into()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn payments(&self) -> Vec<ReceiptPayment> {
        log::debug!("Receipt::payments getter called");
        self.payments.clone()
    }
}

#[derive(Debug, Clone)]
pub enum Store {
    Biedronka,
    Lidl,
    Spolem,
    Other(String),
}

impl Store {
    #[frb(sync, positional)]
    pub fn frb_override_to_string(&self) -> String {
        format!("{}", self)
    }

    #[frb(sync, positional)]
    pub fn from_string(value: &str) -> Self {
        value.into()
    }

    fn to_db_key_string(&self) -> String {
        match self {
            Store::Biedronka => "biedronka".to_owned(),
            Store::Lidl => "lidl".to_owned(),
            Store::Spolem => "spolem".to_owned(),
            Store::Other(v) => v.clone(),
        }
    }
}

impl std::fmt::Display for Store {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            Store::Biedronka => "Biedronka".to_owned(),
            Store::Lidl => "Lidl".to_owned(),
            Store::Spolem => "Społem".to_owned(),
            Store::Other(v) => v.clone(),
        };
        write!(f, "{s}")
    }
}

impl From<String> for Store {
    fn from(value: String) -> Self {
        match value.as_str() {
            "Biedronka" | "biedronka" => Store::Biedronka,
            "Lidl" | "lidl" => Store::Lidl,
            "Społem" | "spolem" => Store::Spolem,
            _ => Store::Other(value),
        }
    }
}

impl From<&str> for Store {
    fn from(value: &str) -> Self {
        match value {
            "Biedronka" | "biedronka" => Store::Biedronka,
            "Lidl" | "lidl" => Store::Lidl,
            "Społem" | "spolem" => Store::Spolem,
            other => Store::Other(other.to_string()),
        }
    }
}

impl sqlx::Type<sqlx::Sqlite> for Store {
    fn type_info() -> sqlx::sqlite::SqliteTypeInfo {
        <String as sqlx::Type<sqlx::Sqlite>>::type_info()
    }
}

impl<'r> sqlx::Decode<'r, sqlx::Sqlite> for Store {
    fn decode(value: sqlx::sqlite::SqliteValueRef<'r>) -> Result<Self, sqlx::error::BoxDynError> {
        let s = <String as sqlx::Decode<sqlx::Sqlite>>::decode(value)?;

        Ok(s.into())
    }
}

impl<'q> sqlx::Encode<'q, sqlx::Sqlite> for Store {
    fn encode(
        self,
        buf: &mut Vec<sqlx::sqlite::SqliteArgumentValue<'q>>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        <String as sqlx::Encode<sqlx::Sqlite>>::encode(self.to_db_key_string(), buf)
    }

    fn encode_by_ref(
        &self,
        buf: &mut Vec<sqlx::sqlite::SqliteArgumentValue<'q>>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        <String as sqlx::Encode<sqlx::Sqlite>>::encode(self.to_db_key_string(), buf)
    }
}

#[derive(Debug, Clone)]
pub enum ReceiptStore {
    Biedronka(Option<String>),
    Lidl(Option<String>),
    Spolem(Option<String>),
    Other(String, Option<String>),
}

impl std::fmt::Display for ReceiptStore {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            ReceiptStore::Biedronka(v) => format!("biedronka: {:?}", v),
            ReceiptStore::Lidl(v) => format!("lidl: {:?}", v),
            ReceiptStore::Spolem(v) => format!("spolem: {:?}", v),
            ReceiptStore::Other(store, v) => format!("other({}): {:?}", store, v),
        };
        write!(f, "{s}")
    }
}

impl ReceiptStore {
    fn from_store(store: &Store, receipt_id: Option<String>) -> Self {
        match store {
            Store::Biedronka => Self::Biedronka(receipt_id),
            Store::Lidl => Self::Lidl(receipt_id),
            Store::Spolem => Self::Spolem(receipt_id),
            Store::Other(store) => Self::Other(store.into(), receipt_id),
        }
    }
}

#[derive(Debug, Clone)]
pub struct ReceiptDiscount {}

impl ReceiptDiscount {
    #[frb(sync)]
    pub fn new() -> Self {
        log::debug!("ReceiptDiscount::new called");
        Self {}
    }
}

#[frb(opaque)]
#[frb(ignore_all)]
#[derive(Debug, Clone)]
pub struct ReceiptItemSummary {
    item: ReceiptItem,
    date: DateTime<Utc>,
    store: Store,
}

impl ReceiptItemSummary {
    #[frb(ignore)]
    pub fn new(item: ReceiptItem, date: DateTime<Utc>, store: Store) -> Self {
        Self { item, date, store }
    }

    #[frb(sync, getter)]
    pub fn item(&self) -> ReceiptItem {
        self.item.clone()
    }

    #[frb(sync, getter)]
    pub fn date(&self) -> DateTime<Utc> {
        self.date.clone()
    }

    #[frb(sync, getter)]
    pub fn store(&self) -> Store {
        self.store.clone()
    }
}

#[frb(opaque)]
#[frb(ignore_all)]
#[derive(Debug, Clone)]
pub struct ReceiptItem {
    pub id: Option<String>,
    pub ean: Option<String>,
    pub name: String,
    pub price: Price,
    pub count: Quantity,
    pub discounts: Vec<ReceiptItemDiscount>,
    pub total: Price,
    pub tax_group: Option<String>,
    pub tax_rate: Option<Price>,
}

impl ReceiptItem {
    #[frb(sync)]
    pub fn new(
        id: Option<String>,
        ean: Option<String>,
        name: String,
        price: Price,
        count: Quantity,
        discounts: Vec<ReceiptItemDiscount>,
        total: Price,
        tax_group: Option<String>,
        tax_rate: Option<Price>,
    ) -> Self {
        log::debug!("ReceiptItem::new called for item: {}", name);
        Self {
            id,
            ean,
            name,
            price: price,
            count: count,
            discounts,
            total: total,
            tax_group,
            tax_rate: tax_rate,
        }
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_id(&self) -> Option<String> {
        log::debug!("ReceiptItem::id getter called");
        self.id.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_ean(&self) -> Option<String> {
        log::debug!("ReceiptItem::ean getter called");
        self.ean.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_name(&self) -> String {
        log::debug!("ReceiptItem::name getter called");
        self.name.clone()
    }

    #[frb(sync, setter)]
    #[inline]
    pub fn set_name(&mut self, value: String) {
        log::debug!("ReceiptItem::name setter called");
        self.name = value;
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_price(&self) -> f32 {
        log::debug!("ReceiptItem::price getter called");
        self.price.into()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_count(&self) -> f32 {
        log::debug!("ReceiptItem::count getter called");
        self.count.into()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_discounts(&self) -> Vec<ReceiptItemDiscount> {
        log::debug!("ReceiptItem::discounts getter called");
        self.discounts.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_total(&self) -> f32 {
        log::debug!("ReceiptItem::total getter called");
        self.total.into()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_tax_group(&self) -> Option<String> {
        log::debug!("ReceiptItem::tax_group getter called");
        self.tax_group.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_tax_rate(&self) -> Option<f32> {
        log::debug!("ReceiptItem::tax_rate getter called");
        self.tax_rate.map(|f| f.into())
    }
}

#[derive(Debug, Clone)]
pub enum ReceiptItemDiscount {
    Value(f32),
    Percent(f32),
}

#[frb(opaque)]
#[frb(ignore_all)]
#[derive(Debug, Clone)]
pub struct ReceiptTaxSummary {
    pub tax_group: Option<String>,
    pub tax_rate: Price,
    pub sales_value: Price,
    pub tax_value: Price,
}

impl ReceiptTaxSummary {
    #[frb(sync)]
    pub fn new(
        tax_group: Option<String>,
        tax_rate: Price,
        value_brutto: Price,
        tax_value: Price,
    ) -> Self {
        log::debug!("ReceiptTaxSummary::new called for group: {:?}", tax_group);
        Self {
            tax_group,
            tax_rate: tax_rate,
            sales_value: value_brutto,
            tax_value: tax_value,
        }
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn tax_group(&self) -> Option<String> {
        log::debug!("ReceiptTaxSummary::tax_group getter called");
        self.tax_group.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn tax_rate(&self) -> f32 {
        log::debug!("ReceiptTaxSummary::tax_rate getter called");
        self.tax_rate.into()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn sales_value(&self) -> f32 {
        log::debug!("ReceiptTaxSummary::sales_value getter called");
        self.sales_value.into()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn tax_value(&self) -> f32 {
        log::debug!("ReceiptTaxSummary::tax_value getter called");
        self.tax_value.into()
    }
}

#[frb(opaque)]
#[frb(ignore_all)]
#[derive(Debug, Clone)]
pub struct ReceiptPayment {
    pub payment_type: ReceiptPaymentType,
    pub value: Price,
}

impl ReceiptPayment {
    #[frb(sync)]
    pub fn new(payment_type: ReceiptPaymentType, value: Price) -> Self {
        log::debug!("ReceiptPayment::new called for type: {:?}", payment_type);
        Self {
            payment_type,
            value: value,
        }
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn payment_type(&self) -> ReceiptPaymentType {
        log::debug!("ReceiptPayment::payment_type getter called");
        self.payment_type.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn value(&self) -> f32 {
        log::debug!("ReceiptPayment::value getter called");
        self.value.into()
    }
}

#[derive(Debug, Clone)]
pub enum ReceiptPaymentType {
    Cash,
    Card,
    Voucher,
    ReturnBottleVoucher,
    StoreCredit,
    Other(String),
}

impl ReceiptPaymentType {
    #[frb(sync, positional)]
    pub fn frb_override_to_string(&self) -> String {
        format!("{}", self)
    }
}

impl std::fmt::Display for ReceiptPaymentType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            ReceiptPaymentType::Cash => "Cash",
            ReceiptPaymentType::Card => "Card",
            ReceiptPaymentType::Voucher => "Voucher",
            ReceiptPaymentType::ReturnBottleVoucher => "ReturnBottleVoucher",
            ReceiptPaymentType::StoreCredit => "StoreCredit",
            ReceiptPaymentType::Other(v) => v.as_str(),
        };
        write!(f, "{s}")
    }
}

impl From<String> for ReceiptPaymentType {
    fn from(value: String) -> Self {
        match value.as_str() {
            "Cash" => ReceiptPaymentType::Cash,
            "Card" => ReceiptPaymentType::Card,
            "Voucher" => ReceiptPaymentType::Voucher,
            "ReturnBottleVoucher" => ReceiptPaymentType::ReturnBottleVoucher,
            "StoreCredit" => ReceiptPaymentType::StoreCredit,
            _ => ReceiptPaymentType::Other(value),
        }
    }
}

impl From<&str> for ReceiptPaymentType {
    fn from(value: &str) -> Self {
        match value {
            "Cash" => ReceiptPaymentType::Cash,
            "Card" => ReceiptPaymentType::Card,
            "Voucher" => ReceiptPaymentType::Voucher,
            "ReturnBottleVoucher" => ReceiptPaymentType::ReturnBottleVoucher,
            "StoreCredit" => ReceiptPaymentType::StoreCredit,
            other => ReceiptPaymentType::Other(other.into()),
        }
    }
}

impl sqlx::Type<sqlx::Sqlite> for ReceiptPaymentType {
    fn type_info() -> sqlx::sqlite::SqliteTypeInfo {
        <String as sqlx::Type<sqlx::Sqlite>>::type_info()
    }
}

impl<'r> sqlx::Decode<'r, sqlx::Sqlite> for ReceiptPaymentType {
    fn decode(value: sqlx::sqlite::SqliteValueRef<'r>) -> Result<Self, sqlx::error::BoxDynError> {
        let s = <String as sqlx::Decode<sqlx::Sqlite>>::decode(value)?;

        Ok(s.into())
    }
}

impl<'q> sqlx::Encode<'q, sqlx::Sqlite> for ReceiptPaymentType {
    fn encode(
        self,
        buf: &mut Vec<sqlx::sqlite::SqliteArgumentValue<'q>>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        <String as sqlx::Encode<sqlx::Sqlite>>::encode(self.to_string(), buf)
    }

    fn encode_by_ref(
        &self,
        buf: &mut Vec<sqlx::sqlite::SqliteArgumentValue<'q>>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        <String as sqlx::Encode<sqlx::Sqlite>>::encode(self.to_string(), buf)
    }
}

impl ReceiptPaymentType {
    #[frb(sync, getter)]
    pub fn values() -> Vec<Self> {
        vec![
            Self::Card,
            Self::Cash,
            Self::Voucher,
            Self::ReturnBottleVoucher,
            Self::StoreCredit,
            Self::Other(String::new()),
        ]
    }
}
