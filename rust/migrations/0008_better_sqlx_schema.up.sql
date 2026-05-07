PRAGMA foreign_keys = OFF;

ALTER TABLE receipts RENAME TO receipts_old;

CREATE TABLE receipts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store TEXT NOT NULL,
  receipt_id TEXT,
  issued_at TEXT NOT NULL,
  total REAL NOT NULL,
  tax_total REAL
);

CREATE INDEX idx_receipts_store ON receipts(store);
CREATE INDEX idx_receipts_issued_at ON receipts(issued_at);

INSERT INTO receipts (id, store, receipt_id, issued_at, total, tax_total)
SELECT
    id,
    COALESCE(
        CASE WHEN store_type IN ('lidl','biedronka','spolem') THEN store_type END,
        store_value
    ),
    CASE WHEN store_type IN ('lidl','biedronka','spolem') THEN store_value ELSE NULL END,
    issued_at,
    total,
    tax_total
FROM receipts_old;

DROP TABLE receipts_old;

-- Recreate tables to fix foreign keys pointing to 'receipts_old'

ALTER TABLE receipt_items RENAME TO receipt_items_old;
CREATE TABLE receipt_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  count REAL NOT NULL,
  total REAL NOT NULL,
  ean TEXT,
  tax_group TEXT,
  tax_rate REAL,
  item_id TEXT,
  FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
);
INSERT INTO receipt_items (id, receipt_id, name, price, count, total, ean, tax_group, tax_rate, item_id)
SELECT id, receipt_id, name, price, count, total, ean, tax_group, tax_rate, item_id FROM receipt_items_old;
DROP TABLE receipt_items_old;

ALTER TABLE receipt_discounts RENAME TO receipt_discounts_old;
CREATE TABLE receipt_discounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
);
INSERT INTO receipt_discounts (id, receipt_id)
SELECT id, receipt_id FROM receipt_discounts_old;
DROP TABLE receipt_discounts_old;

ALTER TABLE receipt_tax_summaries RENAME TO receipt_tax_summaries_old;
CREATE TABLE receipt_tax_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    receipt_id INTEGER NOT NULL,
    tax_group TEXT,
    tax_rate REAL NOT NULL,
    sales_value REAL NOT NULL,
    tax_value REAL NOT NULL,
    FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
);
INSERT INTO receipt_tax_summaries (id, receipt_id, tax_group, tax_rate, sales_value, tax_value)
SELECT id, receipt_id, tax_group, tax_rate, sales_value, tax_value FROM receipt_tax_summaries_old;
DROP TABLE receipt_tax_summaries_old;

ALTER TABLE receipt_payments RENAME TO receipt_payments_old;
CREATE TABLE receipt_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  payment_type TEXT NOT NULL,
  value REAL NOT NULL,
  FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
);
INSERT INTO receipt_payments (id, receipt_id, payment_type, value)
SELECT id, receipt_id, payment_type, value FROM receipt_payments_old;
DROP TABLE receipt_payments_old;

ALTER TABLE receipt_item_discounts RENAME TO receipt_item_discounts_old;
CREATE TABLE receipt_item_discounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_item_id INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'value',
  value REAL NOT NULL DEFAULT 0.0,
  FOREIGN KEY (receipt_item_id) REFERENCES receipt_items(id) ON DELETE CASCADE
);
INSERT INTO receipt_item_discounts (id, receipt_item_id, type, value)
SELECT id, receipt_item_id, type, value FROM receipt_item_discounts_old;
DROP TABLE receipt_item_discounts_old;

ALTER TABLE item_id_ean_map RENAME TO item_id_ean_map_old;
CREATE TABLE item_id_ean_map (
    store TEXT NOT NULL,
    item_id TEXT NOT NULL,
    ean TEXT NOT NULL,
    PRIMARY KEY (store, item_id)
);
INSERT INTO item_id_ean_map (store, item_id, ean)
SELECT
    CASE
        WHEN store_type IN ('lidl', 'biedronka', 'spolem') THEN store_type
        ELSE store_value
    END,
    item_id,
    ean
FROM item_id_ean_map_old;
DROP TABLE item_id_ean_map_old;

PRAGMA foreign_keys = ON;
