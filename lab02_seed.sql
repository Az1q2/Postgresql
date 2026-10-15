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