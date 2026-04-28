CREATE TABLE item_id_ean_map_old (
    store TEXT NOT NULL,
    item_id TEXT NOT NULL,
    ean TEXT NOT NULL,
    PRIMARY KEY(store, item_id)
);

INSERT INTO item_id_ean_map_old (store, item_id, ean)
SELECT
    CASE
        WHEN store_type IN ('lidl', 'biedronka', 'spolem') THEN store_type
        WHEN store_value IS NOT NULL THEN store_value
        ELSE store_type
    END,
    item_id,
    ean
FROM item_id_ean_map;

DROP TABLE item_id_ean_map;

ALTER TABLE item_id_ean_map_old RENAME TO item_id_ean_map;
