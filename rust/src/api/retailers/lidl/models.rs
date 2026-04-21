use chrono::DateTime;
use fix::aliases::si::Centi;
use flutter_rust_bridge::frb;
use serde::Deserialize;

use crate::api::receipts::{self, ReceiptItem, ReceiptPayment, ReceiptTaxSummary};

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketsPage {
    pub page: u16,
    pub size: u16,
    #[serde(rename = "totalCount")]
    pub total_count: u32,
    pub tickets: Vec<TicketPageTicket>,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketPageTicket {
    pub id: String,
    #[serde(rename = "isFavorite")]
    pub is_favorite: bool,
    pub date: String,
    pub currency: Currency,
    #[serde(rename = "totalAmount")]
    pub total_amount: f32,
    #[serde(rename = "storeCode")]
    pub store_code: String,
    #[serde(rename = "articlesCount")]
    pub articles_count: u16,
    #[serde(rename = "couponsUsedCount")]
    pub coupons_used_count: u8,
    pub vendor: Option<serde_json::Value>,
    #[serde(rename = "isHtml")]
    pub is_html: bool,
    #[serde(rename = "hasHtmlDocument")]
    pub has_html_document: bool,
    pub returns: Vec<serde_json::Value>,
    #[serde(rename = "iconUrl")]
    pub icon_url: String,
    pub badges: TicketPageTicketBadges,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct Currency {
    pub code: String,
    pub symbol: String,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketPageTicketBadges {
    pub coupons: u8,
    pub invoice: bool,
    pub returns: u8,
    #[serde(rename = "isAvailable")]
    pub is_available: bool,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct Ticket {
    summary: TicketPageTicket,
    details: TicketDetails,
}

impl TryFrom<Ticket> for receipts::Receipt {
    type Error = anyhow::Error;

    fn try_from(value: Ticket) -> Result<Self, Self::Error> {
        match value.details {
            TicketDetails::NATIVE(ticket_native) => Ok(Self {
                id: None,
                store: receipts::ReceiptStore::Lidl(ticket_native.id),
                issued_at: DateTime::parse_from_rfc3339(&ticket_native.date)
                    .unwrap()
                    .to_utc(),
                items: ticket_native
                    .items_line
                    .into_iter()
                    .map(|i| {
                        let current_unit_price = i
                            .current_unit_price
                            .replace(",", ".")
                            .parse::<f32>()
                            .unwrap();
                        let quantity = i.quantity.replace(",", ".").parse::<f32>().unwrap();
                        let tax_rate = ticket_native
                            .taxes
                            .iter()
                            .find(|f| f.tax_group_name == i.tax_group_name)
                            .map(|t| {
                                t.percentage.replace(",", ".").parse::<f32>().unwrap() / 100.0
                            });

                        ReceiptItem::new(
                            Some(i.code_input),
                            i.name,
                            current_unit_price,
                            quantity,
                            Vec::new(),
                            current_unit_price * quantity,
                            Some(i.tax_group_name),
                            tax_rate,
                        )
                    })
                    .collect(),
                total: Centi::new((ticket_native.total_amount * 100.0) as u32),
                discounts: Vec::new(),
                tax_summary: ticket_native
                    .taxes
                    .into_iter()
                    .map(|t| {
                        ReceiptTaxSummary::new(
                            Some(t.tax_group_name),
                            t.percentage.replace(",", ".").parse::<f32>().unwrap() / 100.0,
                            t.taxable_amount.replace(",", ".").parse::<f32>().unwrap(),
                            t.amount.replace(",", ".").parse::<f32>().unwrap() / 100.0,
                        )
                    })
                    .collect(),
                tax_total: Centi::new(
                    (ticket_native
                        .total_taxes
                        .total_amount
                        .replace(",", ".")
                        .parse::<f32>()
                        .unwrap()
                        * 100.0) as u32,
                ),
                payments: ticket_native
                    .payments
                    .into_iter()
                    .map(|p| {
                        ReceiptPayment::new(
                            match p.payment_type.as_str() {
                                "Cash" => receipts::ReceiptPaymentType::Cash,
                                "CreditCard" => receipts::ReceiptPaymentType::Card,
                                _ => receipts::ReceiptPaymentType::StoreCredit,
                            },
                            p.amount.replace(",", ".").parse::<f32>().unwrap(),
                        )
                    })
                    .collect(),
            }),
            TicketDetails::HTML(_ticket_html) => {
                todo!("Parse HTML for items")
            }
            TicketDetails::OTHER(value) => Err(anyhow::anyhow!("Unknown ticket format {}", value)),
        }
    }
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
#[serde(tag = "ticketType")]
pub enum TicketDetails {
    NATIVE(TicketNative),
    HTML(TicketHtml),
    OTHER(serde_json::Value),
}

impl TicketDetails {
    pub const fn is_native(&self) -> bool {
        matches!(*self, TicketDetails::NATIVE(_))
    }

    pub const fn is_html(&self) -> bool {
        matches!(*self, TicketDetails::HTML(_))
    }

    pub const fn is_other(&self) -> bool {
        matches!(*self, TicketDetails::OTHER(_))
    }
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketNative {
    pub id: String,
    #[serde(rename = "barCode")]
    pub bar_code: String,
    #[serde(rename = "sequenceNumber")]
    pub sequence_number: String,
    pub workstation: String,
    #[serde(rename = "itemsLine")]
    pub items_line: Vec<TicketNativeItemsLine>,
    pub taxes: Vec<TicketNativeTaxes>,
    #[serde(rename = "totalTaxes")]
    pub total_taxes: TicketNativeTotalTaxes,
    #[serde(rename = "couponsUsed")]
    pub coupons_used: Vec<TicketCoupon>,
    #[serde(rename = "returnedNativeTickets")]
    pub returned_native_tickets: Vec<serde_json::Value>,
    #[serde(rename = "isFavorite")]
    pub is_favorite: bool,
    pub date: String,
    #[serde(rename = "totalAmountString")]
    pub total_amount_string: String,
    #[serde(rename = "totalAmount")]
    pub total_amount: f32,
    pub store: TicketStore,
    pub currency: Currency,
    pub payments: Vec<TicketNativePayment>,
    #[serde(rename = "tenderChange")]
    pub tender_change: Vec<serde_json::Value>,
    #[serde(rename = "fiscalDataAt")]
    pub fiscal_data_at: Option<serde_json::Value>,
    #[serde(rename = "fiscalDataCZ")]
    pub fiscal_data_cz: Option<serde_json::Value>,
    #[serde(rename = "fiscalDataDe")]
    pub fiscal_data_de: Option<serde_json::Value>,
    #[serde(rename = "isEmployee")]
    pub is_employee: bool,
    #[serde(rename = "linesScannedCount")]
    pub lines_scanned_count: u8,
    #[serde(rename = "totalDiscount")]
    pub total_discount: String,
    #[serde(rename = "taxExemptTexts")]
    pub tax_exempt_texts: String,
    #[serde(rename = "ustIdNr")]
    pub ust_id_nr: Option<serde_json::Value>,
    #[serde(rename = "languageCode")]
    pub language_code: String,
    #[serde(rename = "operatorId")]
    pub operator_id: Option<serde_json::Value>,
    #[serde(rename = "printedReceiptState")]
    pub printed_receipt_state: String,
    #[serde(rename = "logoUrl")]
    pub logo_url: String,
    #[serde(rename = "watermarkUrl")]
    pub watermark_url: String,
    #[serde(rename = "showCopy")]
    pub show_copy: bool,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketNativeItemsLine {
    #[serde(rename = "currentUnitPrice")]
    pub current_unit_price: String,
    pub quantity: String,
    #[serde(rename = "isWeight")]
    pub is_weight: bool,
    #[serde(rename = "originalAmount")]
    pub original_amount: String,
    pub name: String,
    #[serde(rename = "taxGroupName")]
    pub tax_group_name: String,
    #[serde(rename = "codeInput")]
    pub code_input: String,
    pub discounts: Vec<serde_json::Value>,
    pub deposit: Option<serde_json::Value>,
    #[serde(rename = "giftSerialNumber")]
    pub gift_serial_number: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketNativeTaxes {
    #[serde(rename = "taxGroupName")]
    pub tax_group_name: String,
    pub percentage: String,
    pub amount: String,
    #[serde(rename = "taxableAmount")]
    pub taxable_amount: String,
    #[serde(rename = "netAmount")]
    pub net_amount: String,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketNativeTotalTaxes {
    #[serde(rename = "totalAmount")]
    pub total_amount: String,
    #[serde(rename = "totalTaxableAmount")]
    pub total_taxable_amount: String,
    #[serde(rename = "totalNetAmount")]
    pub total_net_amount: String,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketStore {
    pub id: String,
    pub name: String,
    pub address: String,
    #[serde(rename = "postalCode")]
    pub postal_code: String,
    pub locality: String,
    pub schedule: String,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketNativePayment {
    #[serde(rename = "type")]
    pub payment_type: String,
    pub amount: String,
    pub description: String,
    #[serde(rename = "roundingDifference")]
    pub rounding_difference: String,
    #[serde(rename = "foreignPayment")]
    pub foreign_payment: Option<serde_json::Value>,
    #[serde(rename = "cardInfo")]
    pub card_info: Option<TicketNativePaymentCardInfo>,
    #[serde(rename = "rawPaymentInformationHTML")]
    pub raw_payment_information_html: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketNativePaymentCardInfo {
    #[serde(rename = "accountNumber")]
    pub account_number: String,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketHtml {
    pub id: String,
    #[serde(rename = "barCode")]
    pub bar_code: String,
    #[serde(rename = "couponsUsed")]
    pub coupons_used: Vec<TicketCoupon>,
    #[serde(rename = "returnedHtmlTickets")]
    pub returned_html_tickets: Vec<serde_json::Value>,
    #[serde(rename = "isFavorite")]
    pub is_favorite: bool,
    pub date: String,
    #[serde(rename = "totalAmount")]
    pub total_amount: f32,
    pub store: TicketStore,
    #[serde(rename = "fiscalDataAt")]
    pub fiscal_data_at: Option<serde_json::Value>,
    #[serde(rename = "languageCode")]
    pub language_code: String,
    #[serde(rename = "htmlPrintedReceipt")]
    pub html_printed_receipt: String,
    #[serde(rename = "printedReceiptState")]
    pub printed_receipt_state: String,
    #[serde(rename = "hasInvoice")]
    pub has_invoice: bool,
    #[serde(rename = "logoUrl")]
    pub logo_url: String,
    #[serde(rename = "watermarkUrl")]
    pub watermark_url: String,
    pub codes: Vec<TicketHtmlCode>,
    #[serde(rename = "showCopy")]
    pub show_copy: bool,
    #[serde(rename = "isDeleted")]
    pub is_deleted: bool,
    #[serde(rename = "collectingModel")]
    pub collecting_model: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketCoupon {
    pub title: String,
    pub discount: String,
    #[serde(rename = "block2Description")]
    pub block2_description: String,
    #[serde(rename = "couponTitle")]
    pub coupon_title: String,
    #[serde(rename = "couponDescription")]
    pub coupon_description: String,
}

#[derive(Debug, Deserialize)]
#[allow(unused)]
#[frb(ignore)]
pub struct TicketHtmlCode {
    pub code: String,
    pub format: String,
    pub label: Option<serde_json::Value>,
    pub position: String,
    #[serde(rename = "codeType")]
    pub code_type: String,
    pub size: String,
}

#[cfg(test)]
mod tests {
    use crate::api::retailers::lidl::models::{TicketDetails, TicketsPage};

    #[test]
    fn parse_html() {
        let test_data = r#"{"ticketType":"HTML","id":"240013888620260411403662","barCode":"8881388403662086110426","couponsUsed":[{"title":"Syrop owocowy z witaminami - różne rodzaje","discount":"13% taniej Rabat na maks. 2 szt.","block2Description":"","couponTitle":"13% taniej","couponDescription":"Syrop owocowy z witaminami - różne rodzaje"},{"title":"Krem do smarowania 350 g","discount":"12,99 zł / 1 szt. Rabat na maks. 4 szt.","block2Description":"","couponTitle":"12,99 zł / 1 szt.","couponDescription":"Krem do smarowania 350 g"},{"title":"Gofry 12 sztuk","discount":"13% taniej Rabat na maks. 2 szt.","block2Description":"","couponTitle":"13% taniej","couponDescription":"Gofry 12 sztuk"}],"returnedHtmlTickets":[],"isFavorite":false,"date":"2026-04-11T11:24:10","totalAmount":39.45,"store":{"id":"PL1388","name":"Mielec, ul. Jagiellończyka 19","address":"ul. Jagiellończyka 19","postalCode":"39-300","locality":"Mielec","schedule":""},"fiscalDataAt":null,"languageCode":"pl","htmlPrintedReceipt":"<html><head>\r\n  <meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\"/>\r\n  <style type=text/css>\r\n    .css_doublehigh { font-family:monospace; font-size:100%; transform:scaleY(2.0); display:inline-block; padding-top:5px; padding-bottom:5px; }\r\n    .css_doublewide { font-family:monospace; font-size:200%; transform:scaleY(0.5); display:inline-block; }\r\n    .css_big        { font-family:monospace; font-size:200%; display:inline-block; }\r\n    .css_bold       { font-weight:bold }\r\n    .css_underline  { text-decoration:underline }\r\n    .css_italic     { font-style:italic }\r\n  </style>\r\n</head>\r\n<body>\r\n<pre>\r\n<span class=\"header\" data-till-country=\"PL\" data-receipt-language=\"pl\"><span id=\"header_line_1\"></span>\r\n<span id=\"header_line_2\">Adres siedziby: Poznańska 48, Jankowice </span>\r\n<span id=\"header_line_3\">             62-080 Tarnowo             </span>\r\n<span id=\"header_line_4\">Podg&oacute;rne nr rej: BDO 000002265 Lidl sp. </span>\r\n<span id=\"header_line_5\">             z o. o. sp. k.             </span>\r\n<span id=\"header_line_6\">  ul. Jagiellończyka 19, 39-300 Mielec  </span>\r\n</span><span class=\"purchase_list\"><span id=\"purchase_list_line_1\" class=\"currency\" data-currency=\"zł\">2026-04-11</span>\r\n<span id=\"purchase_list_line_2\"></span>\r\n<span id=\"purchase_list_line_3\" class=\"article\" data-art-id=\"0003364\" data-unit-price=\"18,99\" data-tax-type=\"A\" data-art-description=\"Nutella Krem czek.\">Nutella Krem czek.            </span>\r\n<span id=\"purchase_list_line_4\" class=\"article\" data-art-id=\"0003364\" data-unit-price=\"18,99\" data-tax-type=\"A\" data-art-description=\"Nutella Krem czek.\">                     1 * 18.99 18.99 A</span>\r\n<span id=\"purchase_list_line_5\" class=\"discount\" data-promotion-id=\"100001000-PL-TEMPLATE-PLSD000345300-1\">   Lidl Plus kupon             -6,00</span>\r\n<span id=\"purchase_list_line_6\" class=\"article\" data-art-id=\"5562928\" data-art-quantity=\"2\" data-unit-price=\"10,79\" data-tax-type=\"B\" data-art-description=\"Herbapol Syrop z wit\">Herbapol Syrop z wit          </span>\r\n<span id=\"purchase_list_line_7\" class=\"article\" data-art-id=\"5562928\" data-art-quantity=\"2\" data-unit-price=\"10,79\" data-tax-type=\"B\" data-art-description=\"Herbapol Syrop z wit\">                     2 * 10.79 21.58 B</span>\r\n<span id=\"purchase_list_line_8\" class=\"discount\" data-promotion-id=\"100001006-PL-TEMPLATE-PLAS000160741-1\">   Lidl Plus kupon             -2,80</span>\r\n<span id=\"purchase_list_line_9\" class=\"article\" data-art-id=\"0003529\" data-unit-price=\"5,39\" data-tax-type=\"C\" data-art-description=\"Gofry 32% jaj\">Gofry 32% jaj                 </span>\r\n<span id=\"purchase_list_line_10\" class=\"article\" data-art-id=\"0003529\" data-unit-price=\"5,39\" data-tax-type=\"C\" data-art-description=\"Gofry 32% jaj\">                       1 * 5.39 5.39 C</span>\r\n<span id=\"purchase_list_line_11\" class=\"discount\" data-promotion-id=\"100001006-PL-TEMPLATE-PLAS000161102-1\">   Lidl Plus kupon             -0,70</span>\r\n<span id=\"purchase_list_line_12\" class=\"article\" data-art-id=\"5552611\" data-unit-price=\"2,99\" data-tax-type=\"C\" data-art-description=\"Chleb tost. Pszenny2\">Chleb tost. Pszenny2          </span>\r\n<span id=\"purchase_list_line_13\" class=\"article\" data-art-id=\"5552611\" data-unit-price=\"2,99\" data-tax-type=\"C\" data-art-description=\"Chleb tost. Pszenny2\">                       1 * 2.99 2.99 C</span>\r\n</span><span class=\"vat_info\"><span id=\"vat_info_line_1\" data-tax-type=\"A\" data-tax-percentage=\"23,00\" data-tax-base-amount=\"12,99\" data-tax-amount=\"2,43\">PTU A                            12,99</span>\r\n<span id=\"vat_info_line_2\" data-tax-type=\"A\" data-tax-percentage=\"23,00\" data-tax-base-amount=\"12,99\" data-tax-amount=\"2,43\">Kwota A 23,00%                    2,43</span>\r\n<span id=\"vat_info_line_3\" data-tax-type=\"B\" data-tax-percentage=\"8,00\" data-tax-base-amount=\"18,78\" data-tax-amount=\"1,39\">PTU B                            18,78</span>\r\n<span id=\"vat_info_line_4\" data-tax-type=\"B\" data-tax-percentage=\"8,00\" data-tax-base-amount=\"18,78\" data-tax-amount=\"1,39\">Kwota B 8,00%                     1,39</span>\r\n<span id=\"vat_info_line_5\" data-tax-type=\"C\" data-tax-percentage=\"5,00\" data-tax-base-amount=\"7,68\" data-tax-amount=\"0,37\">PTU C                             7,68</span>\r\n<span id=\"vat_info_line_6\" data-tax-type=\"C\" data-tax-percentage=\"5,00\" data-tax-base-amount=\"7,68\" data-tax-amount=\"0,37\">Kwota C 5,00%                     0,37</span>\r\n<span id=\"vat_info_line_7\">Suma                              4,19</span>\r\n</span><span class=\"purchase_summary\"><span id=\"purchase_summary_1\" class=\"css_big\">Suma PLN</span><span id=\"purchase_summary_1\"> </span><span id=\"purchase_summary_1\"> </span><span id=\"purchase_summary_1\">          </span><span id=\"purchase_summary_1\" class=\"css_big\">39,45</span>\r\n<span id=\"purchase_summary_2\">86 1388      nr:   403662        11:24</span>\r\n<span id=\"purchase_summary_3\" class=\"css_big css_bold\">Suma</span><span id=\"purchase_summary_3\">         </span><span id=\"purchase_summary_3\"> </span><span id=\"purchase_summary_3\">          </span><span id=\"purchase_summary_3\" class=\"css_big css_bold\">39,45</span>\r\n<span id=\"purchase_summary_4\" data-tender-description=\"Karta płatnicza\">Płatność         Karta płatnicza 39,45</span>\r\n<span id=\"purchase_summary_5\" class=\"css_bold\">--------------------------------------</span><span id=\"purchase_summary_5\">  </span><span id=\"purchase_summary_5\"></span>\r\n<span id=\"purchase_summary_6\">--------------------------------------</span><span id=\"purchase_summary_6\"></span>\r\n<span id=\"purchase_summary_7\">&brvbar;     Z Lidl Plus zaoszczędzono      &brvbar;</span>\r\n<span id=\"purchase_summary_8\">&brvbar;              9,50 zł               &brvbar;</span>\r\n<span id=\"purchase_summary_9\">--------------------------------------</span>\r\n</span><span class=\"return_code\"><span id=\"return_code_line_1\" data-return-code=\"0888138800007586110426\"></span>\r\n<span id=\"return_code_line_2\" data-return-code=\"0888138800007586110426\"></span>\r\n</span>\r\n</pre>\r\n</body></html>","printedReceiptState":"PRINTED","hasInvoice":false,"logoUrl":"https://static-tickets.lidlplus.com/images/assets/PL/logo_lidl-PL-new.png","watermarkUrl":"https://static-tickets.lidlplus.com/images/assets/PL/watermark_copy-PL.png","codes":[{"code":"8881388403662086110426","format":"ITF","label":null,"position":"Bottom","codeType":"ReturnInfo","size":"Standard"}],"showCopy":true,"isDeleted":false,"collectingModel":null}"#;

        let obj = serde_json::from_str::<TicketDetails>(test_data);

        if !obj.is_ok() {
            dbg!(&obj);
            assert!(obj.is_ok());
        }

        let obj = obj.unwrap();

        assert!(obj.is_html());
    }

    #[test]
    fn parse_native() {
        let test_data = r#"{"ticketType":"NATIVE","id":"24001388120230520279191","barCode":"8881388279191001200523","sequenceNumber":"279191","workstation":"01","itemsLine":[{"currentUnitPrice":"5,99","quantity":"1","isWeight":false,"originalAmount":"5,99","name":"Szklanka 0447174","taxGroupName":"A","codeInput":"5901105005240","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"10,99","quantity":"2,048","isWeight":true,"originalAmount":"22,51","name":"Kurczak Biesiadny","taxGroupName":"D","codeInput":"2825402020481","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"5,99","quantity":"1","isWeight":false,"originalAmount":"5,99","name":"Ciastka Luppo 182g","taxGroupName":"D","codeInput":"8691707059037","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"5,69","quantity":"1","isWeight":false,"originalAmount":"5,69","name":"Delma margaryna","taxGroupName":"D","codeInput":"8719200240933","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"3,99","quantity":"0,420","isWeight":true,"originalAmount":"1,67","name":"Jabłka Jonagold","taxGroupName":"D","codeInput":"20418250","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"4,28","quantity":"1","isWeight":false,"originalAmount":"4,28","name":"Chleb tost. maślany","taxGroupName":"D","codeInput":"4056489061366","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"3,19","quantity":"1","isWeight":false,"originalAmount":"3,19","name":"Hortex Napój eop20%","taxGroupName":"D","codeInput":"5900500031168","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"7,97","quantity":"1","isWeight":false,"originalAmount":"7,97","name":"Podroby z indyka","taxGroupName":"D","codeInput":"5906735447484","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"10,99","quantity":"1","isWeight":false,"originalAmount":"10,99","name":"Mięs.wiep.n.Szaszł.","taxGroupName":"D","codeInput":"4056489813323","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"7,97","quantity":"1","isWeight":false,"originalAmount":"7,97","name":"Podroby z indyka","taxGroupName":"D","codeInput":"4056489283065","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"2,37","quantity":"1","isWeight":false,"originalAmount":"2,37","name":"Chleb Baltonowski","taxGroupName":"D","codeInput":"5807","discounts":[],"deposit":null,"giftSerialNumber":null},{"currentUnitPrice":"23,92","quantity":"1","isWeight":false,"originalAmount":"23,92","name":"Carlsberg piwo","taxGroupName":"A","codeInput":"5900014071155","discounts":[],"deposit":null,"giftSerialNumber":null}],"taxes":[{"taxGroupName":"A","percentage":"23,00","amount":"5,59","taxableAmount":"29,91","netAmount":"24,32"},{"taxGroupName":"D","percentage":"0,00","amount":"0,00","taxableAmount":"72,63","netAmount":"72,63"}],"totalTaxes":{"totalAmount":"5,59","totalTaxableAmount":"102,54","totalNetAmount":"96,95"},"couponsUsed":[],"returnedNativeTickets":[],"isFavorite":false,"date":"2023-05-20T09:04:28","totalAmountString":"102,54","totalAmount":102.54,"store":{"id":"PL1388","name":"Mielec, ul. Jagiellończyka 19","address":"ul. Jagiellończyka 19","postalCode":"39-300","locality":"Mielec","schedule":""},"currency":{"code":"PLN","symbol":"zł"},"payments":[{"type":"Cash","amount":"100,00","description":"Gotówka","roundingDifference":"0","foreignPayment":null,"cardInfo":null,"rawPaymentInformationHTML":null},{"type":"CreditCard","amount":"2,54","description":"Karta płatnicza","roundingDifference":"0","foreignPayment":null,"cardInfo":{"accountNumber":"************9999"},"rawPaymentInformationHTML":null}],"tenderChange":[],"fiscalDataAt":null,"fiscalDataCZ":null,"fiscalDataDe":null,"isEmployee":false,"linesScannedCount":13,"totalDiscount":"0","taxExemptTexts":"None","ustIdNr":null,"languageCode":"pl","operatorId":null,"printedReceiptState":"PRINTED","logoUrl":"https://static-tickets.lidlplus.com/images/assets/PL/logo_lidl-PL-new.png","watermarkUrl":"https://static-tickets.lidlplus.com/images/assets/PL/watermark_copy-PL.png","showCopy":true}"#;

        let obj = serde_json::from_str::<TicketDetails>(test_data);

        if !obj.is_ok() {
            dbg!(&obj);
            assert!(obj.is_ok());
        }

        let obj = obj.unwrap();

        assert!(obj.is_native());
    }

    #[test]
    fn parse_page() {
        let test_data = r#"{"page":1,"size":25,"totalCount":271,"tickets":[{"id":"240013888620260411403662","isFavorite":false,"date":"2026-04-11T11:24:10+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":39.45,"storeCode":"PL1388","articlesCount":5,"couponsUsedCount":3,"vendor":null,"isHtml":true,"hasHtmlDocument":true,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":3,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240013888520260411332363","isFavorite":false,"date":"2026-04-11T11:17:08+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":43.87,"storeCode":"PL1388","articlesCount":3,"couponsUsedCount":0,"vendor":null,"isHtml":true,"hasHtmlDocument":true,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001084832026033182809","isFavorite":false,"date":"2026-03-31T15:45:37+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":38.03,"storeCode":"PL1084","articlesCount":7,"couponsUsedCount":0,"vendor":null,"isHtml":true,"hasHtmlDocument":true,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240010848120260331112464","isFavorite":false,"date":"2026-03-31T10:15:28+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":6.38,"storeCode":"PL1084","articlesCount":2,"couponsUsedCount":0,"vendor":null,"isHtml":true,"hasHtmlDocument":true,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240016128920260325145705","isFavorite":false,"date":"2026-03-25T19:14:50+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":12.24,"storeCode":"PL1612","articlesCount":2,"couponsUsedCount":0,"vendor":null,"isHtml":true,"hasHtmlDocument":true,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240010848920260325138860","isFavorite":false,"date":"2026-03-25T10:34:16+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":10.79,"storeCode":"PL1084","articlesCount":1,"couponsUsedCount":0,"vendor":null,"isHtml":true,"hasHtmlDocument":true,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001084862026031991217","isFavorite":false,"date":"2026-03-19T10:30:13+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":6.38,"storeCode":"PL1084","articlesCount":2,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240010848420260316134820","isFavorite":false,"date":"2026-03-16T12:52:42+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":33.68,"storeCode":"PL1084","articlesCount":5,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240010849020260312166103","isFavorite":false,"date":"2026-03-12T17:38:03+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":13.99,"storeCode":"PL1084","articlesCount":1,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240010848420260309133667","isFavorite":false,"date":"2026-03-09T20:16:02+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":47.46,"storeCode":"PL1084","articlesCount":9,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001388120260307799310","isFavorite":false,"date":"2026-03-07T11:24:34+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":57.52,"storeCode":"PL1388","articlesCount":6,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240010849020260305164040","isFavorite":false,"date":"2026-03-05T17:20:00+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":9.99,"storeCode":"PL1084","articlesCount":1,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001084832026030377073","isFavorite":false,"date":"2026-03-03T12:33:28+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":9.28,"storeCode":"PL1084","articlesCount":4,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240013888120260228147171","isFavorite":false,"date":"2026-02-28T12:01:05+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":57.94,"storeCode":"PL1388","articlesCount":6,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001388120260221793223","isFavorite":false,"date":"2026-02-21T12:17:38+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":80.12,"storeCode":"PL1388","articlesCount":12,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240013888420260212135857","isFavorite":false,"date":"2026-02-12T14:07:19+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":11.87,"storeCode":"PL1388","articlesCount":13,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001388120260207787219","isFavorite":false,"date":"2026-02-07T11:03:57+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":56.95,"storeCode":"PL1388","articlesCount":6,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001388822026020589374","isFavorite":false,"date":"2026-02-05T15:01:49+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":74.01,"storeCode":"PL1388","articlesCount":10,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001084862026013182569","isFavorite":false,"date":"2026-01-31T16:21:30+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":87.71,"storeCode":"PL1084","articlesCount":12,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240010849020260130156263","isFavorite":false,"date":"2026-01-30T13:01:34+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":4.99,"storeCode":"PL1084","articlesCount":1,"couponsUsedCount":1,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":1,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001084882026012999456","isFavorite":false,"date":"2026-01-29T11:37:30+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":9.45,"storeCode":"PL1084","articlesCount":3,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240010848420260126128361","isFavorite":false,"date":"2026-01-26T10:27:35+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":9.57,"storeCode":"PL1084","articlesCount":3,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240013888420260124132199","isFavorite":false,"date":"2026-01-24T10:30:34+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":35.41,"storeCode":"PL1388","articlesCount":3,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"24001084822026012088887","isFavorite":false,"date":"2026-01-20T15:08:46+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":32.56,"storeCode":"PL1084","articlesCount":4,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}},{"id":"240010848920260120122375","isFavorite":false,"date":"2026-01-20T10:17:39+00:00","currency":{"code":"PLN","symbol":"zł"},"totalAmount":6.3,"storeCode":"PL1084","articlesCount":2,"couponsUsedCount":0,"vendor":null,"isHtml":false,"hasHtmlDocument":false,"returns":[],"iconUrl":"https://static-tickets.lidlplus.com/images/assets/ticketdetail/ticket.png","badges":{"coupons":0,"invoice":false,"returns":0,"isAvailable":true}}]}"#;

        let obj = serde_json::from_str::<TicketsPage>(test_data);

        if !obj.is_ok() {
            dbg!(&obj);
            assert!(obj.is_ok());
        }

        let obj = obj.unwrap();

        dbg!(&obj);

        assert_eq!(obj.tickets.get(0).unwrap().id, "240013888620260411403662");
    }
}
