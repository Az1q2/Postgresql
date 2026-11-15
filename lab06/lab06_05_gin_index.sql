CREATE INDEX IF NOT EXISTS idx_products_attributes_gin
    ON products USING GIN (attributes);

-- Первый запрос с @>
SET enable_seqscan = off;

EXPLAIN ANALYZE
SELECT id, title, attributes
FROM products
WHERE attributes @> '{"brand": "Apple", "screen_inch": 6.7}';

SET enable_seqscan = on;

-- Дополнительно: проверяем что ? тоже использует GIN
SET enable_seqscan = off;

EXPLAIN ANALYZE
SELECT id, title
FROM products
WHERE attributes ? 'screen_inch';

SET enable_seqscan = on;