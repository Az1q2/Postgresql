--Продавцы
INSERT INTO users (full_name, email, role)
SELECT
    'Продавец ' || g,
    'seller' || g || '@example.com',
    'seller'
FROM generate_series(1, 10) g;

--Пользователи или покупатели
INSERT INTO users (full_name, email, role)
SELECT
    'Покупатель ' || g,
    'buyer' || g || '@example.com',
    'buyer'
FROM generate_series(1, 90) g;

-- Магазины пользователей-продавцов
INSERT INTO sellers (user_id, store_name)
SELECT id, 'Магазин ' || id
FROM users
WHERE role = 'seller';

-- Корневые категории
INSERT INTO categories (name)
VALUES ('Электроника'), ('Книги'), ('Одежда');

-- Дочерние категории
INSERT INTO categories (parent_id, name)
SELECT id, 'Телефоны'
FROM categories
WHERE name = 'Электроника';

INSERT INTO categories (parent_id, name)
SELECT id, 'Ноутбуки'
FROM categories
WHERE name = 'Электроника';

-- 500 телефонов, где последние 50 идут с фолс из-за конструкции g<=450, телефоны без описания
INSERT INTO products (
    seller_id, category_id, title, price, is_active
)
SELECT
    1,
    4,
    'Телефон №' || g,
    (random() * 49000 + 1000)::numeric(12,2),
    g <= 450
FROM generate_series(1, 500) AS g;

-- 500 ноутбуков, с описанием, и фолс на последних 50
INSERT INTO products (
    seller_id, category_id, title, description, price, is_active
)
SELECT
    2,
    5,
    'Ноутбук №' || g,
    'Описание ноутбука №' || g,
    (random() * 90000 + 10000)::numeric(12,2),
    g <= 450
FROM generate_series(1, 500) AS g;

-- Остатки для всех товаров
INSERT INTO stock (product_id, quantity)
SELECT id, 20
FROM products;