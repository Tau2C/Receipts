ALTER TABLE receipt_item_discounts ADD COLUMN type TEXT NOT NULL DEFAULT 'value';
ALTER TABLE receipt_item_discounts ADD COLUMN value REAL NOT NULL DEFAULT 0.0;

ALTER TABLE receipt_tax_summary RENAME TO receipt_tax_summary_old;

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
SELECT
    id,
    receipt_id,
    tax_group,
    CAST(tax_rate AS REAL),
    CAST(sales_value AS REAL),
    CAST(tax_value AS REAL)
FROM receipt_tax_summary_old;

DROP TABLE receipt_tax_summary_old;
