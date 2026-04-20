-- Add up migration script here
CREATE TABLE cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  number TEXT NOT NULL
);

CREATE TABLE receipts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_name TEXT NOT NULL,
  issued_at TEXT NOT NULL,
  total REAL NOT NULL
);

CREATE TABLE receipt_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  count REAL NOT NULL,
  total REAL NOT NULL,
  FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
);

CREATE TABLE receiptProviders (
  name TEXT PRIMARY KEY,
  lastFetchDateTime TEXT
);
