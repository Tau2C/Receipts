use chrono::DateTime;
use fix::aliases::si::Centi;
use flutter_rust_bridge::frb;
use rust_decimal::prelude::Zero;
use serde::Deserialize;

use crate::api::receipts::{
    self, ReceiptItemDiscount, ReceiptPayment, ReceiptPaymentType, ReceiptTaxSummary,
};

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct Receipt {
    pub id: String,
    pub date: String,
    pub total_price: f32,
    pub store_name: String,
    pub receipt_num: String,
    pub is_e_receipt_available: bool,
    pub total_discount: f32,
    pub store_id: String,
    pub cash_register_id: u8,
    pub id_from_receipt: String,
    pub cashier_id: Option<String>,
    pub basket_id: Option<String>,
    pub invoice_id: Option<String>,
    pub total_tax: f32,
    pub due_change: f32,
    pub items: Vec<Item>,
    pub payments: Vec<Payment>,
    pub tax_summaries: Vec<TaxSummary>,
    pub receipt_barcode: String,
    pub extended_transaction_number: String,
    pub collected_returnable_packagings_value: f32,
    pub sold_returnable_packagings_value: f32,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct Item {
    pub position: String,
    pub name: String,
    pub quantity: f32,
    pub unit_price: f32,
    pub total_discount: f32,
    pub total_price_without_discount: f32,
    pub total_price: f32,
    pub ean: String,
    pub vat_rate: u8,
    pub vat_fiscal_code: String,
    pub measure_unit: String,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct Payment {
    pub payment_type: String,
    pub name: String,
    pub value: f32,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TaxSummary {
    pub vat_rate: u8,
    pub sale_value: f32,
    pub tax_value: f32,
    pub vat_fiscal_code: String,
}

impl From<Receipt> for receipts::Receipt {
    fn from(value: Receipt) -> Self {
        log::debug!("biedronka::Receipt::from");
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
                        if i.total_discount.is_zero() {
                            Vec::new()
                        } else {
                            vec![ReceiptItemDiscount::Value(i.total_discount)]
                        },
                        i.total_price,
                        Some(i.vat_fiscal_code),
                        Some(i.vat_rate as f32 / 100.0),
                    )
                })
                .collect(),
            total: Centi::new((value.total_price * 100.0) as u32),
            discounts: Vec::new(),
            tax_summary: value
                .tax_summaries
                .into_iter()
                .map(|t| {
                    ReceiptTaxSummary::new(
                        Some(t.vat_fiscal_code),
                        (t.vat_rate as f32) / 100.0,
                        t.sale_value + t.tax_value,
                        t.tax_value,
                    )
                })
                .collect(),
            tax_total: Centi::new((value.total_tax * 100.0) as u32),
            payments: value
                .payments
                .into_iter()
                .map(|p| {
                    let payment_type = match p.payment_type.as_str() {
                        "Card" => ReceiptPaymentType::Card,
                        "DiscountVoucher" => {
                            if p.name.contains("zwrot opak (PET/CAN)") {
                                ReceiptPaymentType::ReturnBottleVoucher
                            } else {
                                ReceiptPaymentType::Voucher
                            }
                        }
                        "Cash" => ReceiptPaymentType::Cash,
                        _ => ReceiptPaymentType::Other(p.name),
                    };
                    ReceiptPayment::new(payment_type, p.value)
                })
                .collect(),
        }
    }
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TransactionsPage {
    pub transactions: Vec<Transaction>,
    pub page_number: u8,
    pub page_count: u8,
    pub previous_page: Option<u8>,
    pub next_page: Option<u8>,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct Transaction {
    pub id: String,
    pub date: String,
    pub total_price: f32,
    pub store_name: String,
    pub receipt_num: String,
    pub is_e_receipt_available: bool,
}
