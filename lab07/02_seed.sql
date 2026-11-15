-- 1. Пользователи: 10 продавцов + 90 покупателей
INSERT INTO users (full_name, email, role)
SELECT
    'Продавец ' || g,
    'seller' || g || '@marketplace.ru',
    'seller'
FROM generate_series(1, 10) g;

INSERT INTO users (full_name, email, role)
SELECT
    'Покупатель ' || g,
    'buyer' || g || '@marketplace.ru',
    'buyer'
FROM generate_series(1, 90) g;

-- 2. Магазины продавцов (10 магазинов для первых 10 пользователей)
INSERT INTO sellers (user_id, store_name, is_verified)
SELECT
    id,
    'Store ' || id,
    (id % 2 = 0)
FROM users
WHERE role = 'seller';

-- 3. Иерархия категорий
-- Корневые категории
INSERT INTO categories (name)
VALUES ('Электроника'), ('Книги'), ('Одежда');

-- Дочерние категории для «Электроника»
INSERT INTO categories (parent_id, name)
SELECT id, 'Телефоны' FROM categories WHERE name = 'Электроника';

INSERT INTO categories (parent_id, name)
SELECT id, 'Ноутбуки' FROM categories WHERE name = 'Электроника';

-- 4. Каталог товаров с JSONB-характеристиками

-- 500 телефонов (category_id = 4, продавец 1)
INSERT INTO products (
    seller_id, category_id, title, description, price, is_active, attributes
)
SELECT
    1,
    4,
    'Телефон №' || g,
    'Смартфон с диагональю экрана и высокой производительностью',
    (random() * 49000 + 1000)::numeric(12,2),
    g <= 450,
    jsonb_build_object(
        'brand',       (ARRAY['Samsung', 'Apple', 'Xiaomi', 'Huawei'])[g % 4 + 1],
        'screen_inch', round((6.1 + (g % 5) * 0.15)::numeric, 2),
        'ram_gb',      (ARRAY[4, 6, 8, 12])[g % 4 + 1],
        'color',       (ARRAY['black', 'white', 'blue', 'red'])[g % 4 + 1]
    )
FROM generate_series(1, 500) AS g;

-- 500 ноутбуков (category_id = 5, продавец 2)
INSERT INTO products (
    seller_id, category_id, title, description, price, is_active, attributes
)
SELECT
    2,
    5,
    'Ноутбук №' || g,
    'Портативный компьютер для работы и учёбы',
    (random() * 90000 + 10000)::numeric(12,2),
    g <= 450,
    jsonb_build_object(
        'brand',       (ARRAY['Lenovo', 'ASUS', 'Dell', 'HP'])[g % 4 + 1],
        'ram_gb',      (ARRAY[8, 16, 32])[g % 3 + 1],
        'storage_gb',  (ARRAY[256, 512, 1024])[g % 3 + 1],
        'os',          (ARRAY['Linux', 'Windows', 'Linux'])[g % 3 + 1]
    )
FROM generate_series(1, 500) AS g;

-- 2 демонстрационных товара с одинаковой ценой (для демонстрации RANK vs DENSE_RANK)
INSERT INTO products (seller_id, category_id, title, description, price, is_active, attributes)
VALUES 
(1, 4, 'Телефон №1001', 'Демонстрационный товар: повтор цены', 24719.00, true, '{"brand": "Xiaomi", "ram_gb": 8}'::jsonb),
(1, 4, 'Телефон №1002', 'Демонстрационный товар: повтор цены', 24719.00, true, '{"brand": "Samsung", "ram_gb": 8}'::jsonb);

-- 5. Складские остатки (по 20 шт. для каждого товара)
INSERT INTO stock (product_id, quantity)
SELECT id, 20
FROM products;

-- 6. Корзины для всех пользователей
INSERT INTO carts (user_id)
SELECT id
FROM users;

-- Позиции в корзинах (по 2 позиции в каждой корзине)
INSERT INTO cart_items (cart_id, product_id, quantity)
SELECT id, 1, 1 FROM carts;

INSERT INTO cart_items (cart_id, product_id, quantity)
SELECT id, 2, 2 FROM carts;

-- 7. Адреса пользователей
INSERT INTO addresses (user_id, city, street, house, is_default)
SELECT
    id,
    'Москва',
    'Учебная улица',
    'Дом ' || id,
    true
FROM users;

-- 8. Заказы: 1000 заказов, распределённых по датам за последние 20 дней
-- (необходимо для работы оконной аналитики LAG/LEAD и нарастающих итогов)
INSERT INTO orders (user_id, status, total_amount, created_at)
SELECT
    (g - 1) % 100 + 1,
    (ARRAY['new', 'paid', 'completed', 'paid', 'completed'])[g % 5 + 1],
    17698.34,
    now() - ((1000 - g) / 50 * INTERVAL '1 day')
FROM generate_series(1, 1000) AS g;

-- 9. Позиции заказов
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT
    id,
    (id % 10) + 1,
    1,
    total_amount
FROM orders;

-- 10. Платежи по заказам
INSERT INTO payments (order_id, amount, status, paid_at)
SELECT
    id,
    total_amount,
    CASE WHEN status IN ('paid', 'completed') THEN 'completed' ELSE 'pending' END,
    CASE WHEN status IN ('paid', 'completed') THEN created_at + INTERVAL '5 minutes' ELSE NULL END
FROM orders;

-- 11. Отзывы пользователей (на первые товары)
INSERT INTO reviews (user_id, product_id, score, comment, created_at)
SELECT
    id,
    ((id - 1) % 5) + 1,
    (id - 1) % 5 + 1,
    'Тестовый отзыв пользователя №' || id,
    now() - (id * INTERVAL '1 hour')
FROM users;

-- 12. Доставка заказов
INSERT INTO deliveries (order_id, address_id, delivery_status, tracking_code, shipped_at)
SELECT
    o.id,
    o.user_id,
    CASE 
        WHEN o.status = 'completed' THEN 'delivered'
        WHEN o.status = 'paid' THEN 'in_transit'
        ELSE 'processing'
    END,
    'TRK-' || o.id || '-' || trunc(random() * 9000 + 1000)::text,
    CASE WHEN o.status IN ('paid', 'completed') THEN o.created_at + INTERVAL '1 hour' ELSE NULL END
FROM orders o;
