ALTER TABLE receipt_tax_summaries RENAME TO receipt_tax_summaries_new;

CREATE TABLE receipt_tax_summary (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  tax_group TEXT NOT NULL,
  tax_rate TEXT NOT NULL,
  sales_value TEXT NOT NULL,
  tax_value TEXT NOT NULL,
  FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
);

INSERT INTO receipt_tax_summary (id, receipt_id, tax_group, tax_rate, sales_value, tax_value)
SELECT
    id,
    receipt_id,
    COALESCE(tax_group, ''),
    CAST(tax_rate AS TEXT),
    CAST(sales_value AS TEXT),
    CAST(tax_value AS TEXT)
FROM receipt_tax_summaries_new;

DROP TABLE receipt_tax_summaries_new;
