-- Add down migration script here
PRAGMA foreign_keys = OFF;

CREATE TABLE receipts_old (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_name TEXT NOT NULL,
  issued_at TEXT NOT NULL,
  total REAL NOT NULL
);

INSERT INTO receipts_old (id, store_name, issued_at, total)
SELECT id, store_name, issued_at, total FROM receipts;

DROP TABLE receipts;
ALTER TABLE receipts_old RENAME TO receipts;

CREATE TABLE receipt_items_old (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  count REAL NOT NULL,
  total REAL NOT NULL,
  FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
);

INSERT INTO receipt_items_old (id, receipt_id, name, price, count, total)
SELECT id, receipt_id, name, price, count, total FROM receipt_items;

DROP TABLE receipt_items;
ALTER TABLE receipt_items_old RENAME TO receipt_items;

DROP TABLE IF EXISTS receipt_item_discounts;
DROP TABLE IF EXISTS receipt_discounts;
DROP TABLE IF EXISTS receipt_tax_summary;
DROP TABLE IF EXISTS receipt_payments;
DROP TABLE IF EXISTS retailers;

PRAGMA foreign_keys = ON;
