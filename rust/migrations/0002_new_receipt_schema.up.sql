-- Add up migration script here
PRAGMA foreign_keys = ON;

ALTER TABLE receipts ADD COLUMN store_type TEXT;
ALTER TABLE receipts ADD COLUMN store_value TEXT;
ALTER TABLE receipts ADD COLUMN tax_total REAL;

-- NOTE:
-- We keep existing store_name for backward compatibility.
-- You can migrate data later if needed.
-- Or drop it in a future migration.

ALTER TABLE receipt_items ADD COLUMN ean TEXT;
ALTER TABLE receipt_items ADD COLUMN tax_group TEXT;
ALTER TABLE receipt_items ADD COLUMN tax_rate REAL;

CREATE TABLE IF NOT EXISTS receipt_item_discounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_item_id INTEGER NOT NULL,
  FOREIGN KEY (receipt_item_id) REFERENCES receipt_items(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS receipt_discounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS receipt_tax_summary (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,

  tax_group TEXT NOT NULL,
  tax_rate TEXT NOT NULL,
  sales_value TEXT NOT NULL,
  tax_value TEXT NOT NULL,

  FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS receipt_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,

  payment_type TEXT NOT NULL,
  value REAL NOT NULL,

  FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS retailers (
  name TEXT PRIMARY KEY,
  last_fetch_date_time TEXT
);
