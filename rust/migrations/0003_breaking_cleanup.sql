-- Add migration script here
--
-- Drop the legacy receiptProviders table
DROP TABLE IF EXISTS receiptProviders;

-- Turn off foreign keys temporarily so we can drop the receipts table
PRAGMA foreign_keys = OFF;

-- 1. Create a new table without the `store_name` column
CREATE TABLE receipts_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  issued_at TEXT NOT NULL,
  total REAL NOT NULL,
  store_type TEXT,
  store_value TEXT,
  tax_total REAL
);

-- 2. Copy the data from the old table to the new table
INSERT INTO receipts_new (id, issued_at, total, store_type, store_value, tax_total)
SELECT id, issued_at, total, store_type, store_value, tax_total
FROM receipts;

-- 3. Drop the old table
DROP TABLE receipts;

-- 4. Rename the new table to the original name
ALTER TABLE receipts_new RENAME TO receipts;

-- Turn foreign keys back on
PRAGMA foreign_keys = ON;
