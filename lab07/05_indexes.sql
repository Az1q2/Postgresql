-- B-tree: Фильтрация и сортировка товаров по цене
CREATE INDEX IF NOT EXISTS idx_products_price
    ON products (price);

-- B-tree: Внешние ключи товаров (частые JOIN и фильтры каталога)
CREATE INDEX IF NOT EXISTS idx_products_category
    ON products (category_id);

CREATE INDEX IF NOT EXISTS idx_products_seller
    ON products (seller_id);

-- B-tree: Личный кабинет покупателя (история заказов пользователя)
CREATE INDEX IF NOT EXISTS idx_orders_user
    ON orders (user_id);

-- B-tree: Аналитика продаж по товарам
CREATE INDEX IF NOT EXISTS idx_order_items_product
    ON order_items (product_id);

-- B-tree: Карточка товара (загрузка отзывов к товару)
CREATE INDEX IF NOT EXISTS idx_reviews_product
    ON reviews (product_id);

-- GIN: Полнотекстовый и фрагментный поиск внутри характеристик JSONB
CREATE INDEX IF NOT EXISTS idx_products_attributes_gin
    ON products USING GIN (attributes);


-- Проверка 1: B-tree индекс на price (Index Scan + Zero-cost sort)
EXPLAIN ANALYZE
SELECT id, title, price
FROM products
WHERE price > 95000
ORDER BY price DESC;

-- Проверка 2: GIN-индекс на JSONB (Bitmap Index Scan по предикату @>)
SET enable_seqscan = off;

EXPLAIN ANALYZE
SELECT id, title, attributes
FROM products
WHERE attributes @> '{"brand": "Apple", "screen_inch": 6.7}';

SET enable_seqscan = on;
