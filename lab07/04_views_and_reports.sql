-- 1. Витрина каталога: товары с категорией, магазином, ценой и рейтингом
CREATE OR REPLACE VIEW v_product_catalog AS
SELECT
    p.id AS product_id,
    p.title,
    c.name AS category_name,
    s.store_name,
    p.price,
    p.rating,
    p.is_active,
    p.attributes
FROM products p
JOIN categories c ON c.id = p.category_id
JOIN sellers s ON s.id = p.seller_id;

-- 2. Витрина статистики по категориям: число товаров и средняя цена
CREATE OR REPLACE VIEW v_category_product_stats AS
SELECT
    c.id AS category_id,
    c.name AS category_name,
    COUNT(p.id) AS total_products,
    COUNT(p.id) FILTER (WHERE p.is_active = TRUE) AS active_products,
    ROUND(COALESCE(AVG(p.price), 0.00), 2) AS avg_price
FROM categories c
LEFT JOIN products p ON p.category_id = c.id
GROUP BY c.id, c.name;

-- 3. Витрина ежедневных продаж платформы
CREATE OR REPLACE VIEW v_daily_sales AS
SELECT
    o.created_at::date AS order_date,
    COUNT(DISTINCT o.id) AS total_orders,
    SUM(oi.quantity * oi.unit_price) AS daily_revenue,
    ROUND(AVG(oi.quantity * oi.unit_price), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status <> 'cancelled'
GROUP BY o.created_at::date;


-- Отчёт 1: Иерархическое дерево категорий (Рекурсивный CTE)
-- Обходит дерево категорий от корня вглубь с расчётом уровня вложенности (depth)
WITH RECURSIVE category_tree AS (
    SELECT
        c.id,
        c.parent_id,
        c.name,
        0 AS depth
    FROM categories c
    WHERE c.parent_id IS NULL

    UNION ALL

    SELECT
        child.id,
        child.parent_id,
        child.name,
        parent.depth + 1
    FROM categories child
    JOIN category_tree parent ON child.parent_id = parent.id
)
SELECT id, parent_id, name, depth
FROM category_tree
ORDER BY depth, id;


-- Отчёт 2: Топ-3 самых дорогих товаров в каждой категории (Оконная функция DENSE_RANK)
WITH ranked_products AS (
    SELECT
        c.name AS category_name,
        p.title,
        p.price,
        DENSE_RANK() OVER (
            PARTITION BY p.category_id
            ORDER BY p.price DESC
        ) AS rank_in_category
    FROM products p
    JOIN categories c ON c.id = p.category_id
    WHERE p.is_active = TRUE
)
SELECT category_name, title, price, rank_in_category
FROM ranked_products
WHERE rank_in_category <= 3
ORDER BY category_name, rank_in_category, price DESC;


-- Отчёт 3: Нарастающий итог выручки площадки по дням (Оконная агрегация)
SELECT
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (ORDER BY order_date) AS running_total_revenue
FROM v_daily_sales
ORDER BY order_date;


-- Отчёт 4: Динамика изменения выручки день-ко-дню (Функции смещения LAG и LEAD)
SELECT
    order_date,
    daily_revenue,
    daily_revenue - LAG(daily_revenue) OVER (ORDER BY order_date) AS growth_vs_prev_day,
    ROUND(
        ((daily_revenue - LAG(daily_revenue) OVER (ORDER BY order_date)) * 100.0) 
        / NULLIF(LAG(daily_revenue) OVER (ORDER BY order_date), 0), 2
    ) AS growth_pct
FROM v_daily_sales
ORDER BY order_date;


-- Отчёт 5: Доля продавца в общей стоимости товаров категории (Партиции)
SELECT
    s.store_name,
    c.name AS category_name,
    SUM(p.price) AS seller_category_worth,
    ROUND(
        SUM(p.price) * 100.0 / SUM(SUM(p.price)) OVER (PARTITION BY p.category_id), 2
    ) AS share_in_category_pct
FROM products p
JOIN sellers s ON s.id = p.seller_id
JOIN categories c ON c.id = p.category_id
WHERE p.is_active = TRUE
GROUP BY s.store_name, c.name, p.category_id
ORDER BY c.name, share_in_category_pct DESC;


-- Отчёт 6: Выборка по слабоструктурированным JSONB-характеристикам
SELECT
    id,
    title,
    attributes->>'brand' AS brand,
    attributes->>'ram_gb' AS ram_gb,
    attributes->>'screen_inch' AS screen_inch
FROM products
WHERE attributes @> '{"brand": "Samsung"}'
ORDER BY price DESC
LIMIT 5;
