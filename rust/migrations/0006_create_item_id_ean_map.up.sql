-- Create a table to map store-specific item IDs to EANs
CREATE TABLE IF NOT EXISTS item_id_ean_map (
    store TEXT NOT NULL,
    item_id TEXT NOT NULL,
    ean TEXT NOT NULL,
    PRIMARY KEY (store, item_id)
);
