ALTER TABLE item_id_ean_map RENAME TO item_id_ean_map_old;

CREATE TABLE item_id_ean_map (
    store_type TEXT NOT NULL,
    store_value TEXT,
    item_id TEXT NOT NULL,
    ean TEXT NOT NULL,
    PRIMARY KEY (store_type, store_value, item_id)
);

INSERT INTO item_id_ean_map (store_type, store_value, item_id, ean)
SELECT
    CASE
        WHEN store IN ('lidl', 'biedronka', 'spolem') THEN store
        ELSE 'other'
    END,

    CASE
        WHEN store IN ('lidl', 'biedronka', 'spolem') THEN ''
        ELSE store
    END,
    item_id,
    ean
FROM item_id_ean_map_old;

DROP TABLE item_id_ean_map_old;
