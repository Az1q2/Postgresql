-- Представление каталога: товары с названиями категорий и магазинов
CREATE OR REPLACE VIEW product_catalog AS
SELECT
    p.id product_id,
    p.title,
    c.name category,
    s.store_name seller,
    p.price
FROM products p
INNER JOIN categories c ON c.id = p.category_id
INNER JOIN sellers s ON s.id = p.seller_id;

-- Представление статистики: количество товаров и средняя цена в каждой категории
CREATE OR REPLACE VIEW category_product_stats AS
SELECT
    c.id category_id,
    c.name category,
    COUNT(p.id) products_count,
    AVG(p.price) avg_price
FROM categories c
LEFT JOIN products p ON p.category_id = c.id
GROUP BY c.id, c.name;

-- Обращение к каталогу: первые 10 товаров
SELECT product_id, title, category, seller, price
FROM product_catalog
ORDER BY product_id
LIMIT 10;

-- Обращение к статистике: все категории, включая категории без товаров
SELECT category_id, category, products_count, avg_price
FROM category_product_stats
ORDER BY category_id;
