use chrono::{DateTime, Utc};
use fix::aliases::si::{Centi, Milli};
use flutter_rust_bridge::frb;
use sqlx::prelude::FromRow;
use strum_macros::{EnumString, IntoStaticStr};

#[frb(opaque, ignore_all)]
#[derive(Debug, Clone, FromRow)]
pub struct Receipt {
    pub id: Option<u32>,

    pub store: ReceiptStore,
    pub issued_at: DateTime<Utc>,

    pub items: Vec<ReceiptItem>,
    pub total: Centi<u32>,
    pub discounts: Vec<ReceiptDiscount>,
    pub tax_summary: Vec<ReceiptTaxSummary>,
    pub tax_total: Centi<u32>,

    pub payments: Vec<ReceiptPayment>,
}

impl Receipt {
    #[frb(sync)]
    pub fn new(
        id: Option<u32>,
        store: ReceiptStore,
        issued_at: DateTime<Utc>,

        items: Vec<ReceiptItem>,
        total: f32,
        discounts: Vec<ReceiptDiscount>,
        tax_summary: Vec<ReceiptTaxSummary>,
        tax_total: f32,

        payments: Vec<ReceiptPayment>,
    ) -> Self {
        log::debug!("Receipt::new called for store: {:?}", store);
        Self {
            id,
            store,
            issued_at,
            items,
            total: Centi::new((total * 100.0) as u32),
            discounts,
            tax_summary,
            tax_total: Centi::new((tax_total * 100.0) as u32),
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
    pub fn store(&self) -> ReceiptStore {
        log::debug!("Receipt::store getter called");
        self.store.clone()
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn issued_at(&self) -> DateTime<Utc> {
        log::debug!("Receipt::issued_at getter called");
        self.issued_at
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
        self.total.bits as f32 / 100.0
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
        self.tax_total.bits as f32 / 100.0
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn payments(&self) -> Vec<ReceiptPayment> {
        log::debug!("Receipt::payments getter called");
        self.payments.clone()
    }
}

#[derive(Debug, Clone)]
pub enum ReceiptStore {
    Other(String),
    Biedronka(String),
    Lidl(String),
    Spolem(String),
}

impl ReceiptStore {
    pub(crate) unsafe fn from_parts(kind: &str, value: String) -> Self {
        log::debug!(
            "ReceiptStore::from_parts called with kind: {}, value: {}",
            kind,
            value
        );
        match kind {
            "biedronka" => Self::Biedronka(value),
            "lidl" => Self::Lidl(value),
            "spolem" => Self::Spolem(value),
            _ => Self::Other(value),
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

#[derive(Debug, Clone)]
#[frb]
pub struct ReceiptItemSummary {
    item: ReceiptItem,
    date: DateTime<Utc>,
    store: ReceiptStore,
}

impl ReceiptItemSummary {
    #[frb(ignore)]
    pub fn new(item: ReceiptItem, date: DateTime<Utc>, store: ReceiptStore) -> Self {
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
    pub fn store(&self) -> ReceiptStore {
        self.store.clone()
    }
}

#[derive(Debug, Clone)]
pub struct ReceiptItem {
    ean: Option<String>,
    name: String,
    price: Centi<u16>,
    count: Milli<u32>,
    discounts: Vec<ReceiptItemDiscount>,
    total: Centi<u32>,
    tax_group: Option<String>,
    tax_rate: Option<Centi<u16>>,
}

impl ReceiptItem {
    #[frb(sync)]
    pub fn new(
        ean: Option<String>,
        name: String,
        price: f32,
        count: f32,
        discounts: Vec<ReceiptItemDiscount>,
        total: f32,
        tax_group: Option<String>,
        tax_rate: Option<f32>,
    ) -> Self {
        log::debug!("ReceiptItem::new called for item: {}", name);
        Self {
            ean,
            name,
            price: Centi::new((price * 100.0) as u16),
            count: Milli::new((count * 1000.0) as u32),
            discounts,
            total: Centi::new((total * 100.0) as u32),
            tax_group,
            tax_rate: tax_rate.map(|f| Centi::new((f * 100.0) as u16)),
        }
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
        self.price.bits as f32 / 100.0
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn get_count(&self) -> f32 {
        log::debug!("ReceiptItem::count getter called");
        self.count.bits as f32 / 1000.0
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
        self.total.bits as f32 / 100.0
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
        self.tax_rate.map(|f| f.bits as f32 / 100.0)
    }
}

#[derive(Debug, Clone)]
pub struct ReceiptItemDiscount {}

impl ReceiptItemDiscount {
    #[frb(sync)]
    pub fn new() -> Self {
        log::debug!("ReceiptItemDiscount::new called");
        Self {}
    }
}

#[derive(Debug, Clone)]
pub struct ReceiptTaxSummary {
    tax_group: Option<String>,
    tax_rate: Centi<u16>,
    sales_value: Centi<u16>,
    tax_value: Centi<u16>,
}

impl ReceiptTaxSummary {
    #[frb(sync)]
    pub fn new(tax_group: Option<String>, tax_rate: f32, sales_value: f32, tax_value: f32) -> Self {
        log::debug!("ReceiptTaxSummary::new called for group: {:?}", tax_group);
        Self {
            tax_group,
            tax_rate: Centi::new((tax_rate * 100.0) as u16),
            sales_value: Centi::new((sales_value * 100.0) as u16),
            tax_value: Centi::new((tax_value * 100.0) as u16),
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
        self.tax_rate.bits as f32 / 100.0
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn sales_value(&self) -> f32 {
        log::debug!("ReceiptTaxSummary::sales_value getter called");
        self.sales_value.bits as f32 / 100.0
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn tax_value(&self) -> f32 {
        log::debug!("ReceiptTaxSummary::tax_value getter called");
        self.tax_value.bits as f32 / 100.0
    }
}

#[derive(Debug, Clone)]
pub struct ReceiptPayment {
    payment_type: ReceiptPaymentType,
    value: Centi<u32>,
}

impl ReceiptPayment {
    #[frb(sync)]
    pub fn new(payment_type: ReceiptPaymentType, value: f32) -> Self {
        log::debug!("ReceiptPayment::new called for type: {:?}", payment_type);
        Self {
            payment_type,
            value: Centi::new((value * 100.0) as u32),
        }
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn payment_type(&self) -> ReceiptPaymentType {
        log::debug!("ReceiptPayment::payment_type getter called");
        self.payment_type
    }

    #[frb(sync, getter)]
    #[inline]
    pub fn value(&self) -> f32 {
        log::debug!("ReceiptPayment::value getter called");
        self.value.bits as f32 / 100.0
    }
}

#[derive(Debug, Clone, Copy, EnumString, IntoStaticStr)]
pub enum ReceiptPaymentType {
    Cash,
    Card,
    Voucher,
    StoreCredit,
}
