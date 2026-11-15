-- Создаём индексы
CREATE INDEX IF NOT EXISTS idx_products_price
    ON products (price);

CREATE INDEX IF NOT EXISTS idx_products_category
    ON products (category_id);

-- Запрос 1
EXPLAIN ANALYZE
SELECT id, title, price
FROM products
WHERE price > 95000
ORDER BY price DESC;


-- Запрос 2
EXPLAIN ANALYZE
SELECT p.id, p.title, c.name, COUNT(r.id)
FROM products p
JOIN categories c ON c.id = p.category_id
LEFT JOIN reviews r ON r.product_id = p.id
WHERE p.category_id = 4
GROUP BY p.id, p.title, c.name;
