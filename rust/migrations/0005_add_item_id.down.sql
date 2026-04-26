-- Safe down migration for removing the 'item_id' column from 'receipt_items'

PRAGMA foreign_keys=off;

CREATE TABLE receipt_items_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  count REAL NOT NULL,
  total REAL NOT NULL,
  ean TEXT,
  tax_group TEXT,
  tax_rate REAL,
  FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
);

INSERT INTO receipt_items_new (id, receipt_id, name, price, count, total, ean, tax_group, tax_rate)
SELECT id, receipt_id, name, price, count, total, ean, tax_group, tax_rate
FROM receipt_items;

DROP TABLE receipt_items;

ALTER TABLE receipt_items_new RENAME TO receipt_items;

PRAGMA foreign_keys=on;
