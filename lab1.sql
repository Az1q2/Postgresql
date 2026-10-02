-- 1. Пользователи
CREATE TABLE users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE CHECK (email LIKE '%_@_%'),
    phone TEXT UNIQUE,
    role TEXT NOT NULL DEFAULT 'buyer' CHECK (role IN ('buyer', 'seller', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Продавцы (связь 1:0..1 с пользователем)
CREATE TABLE sellers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    store_name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Категории (иерархия: список смежности)
CREATE TABLE categories (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id BIGINT REFERENCES categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    name TEXT NOT NULL UNIQUE,
    CONSTRAINT chk_category_not_self_parent CHECK (parent_id IS NULL OR parent_id <> id)
);

-- 4. Товары
CREATE TABLE products (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id BIGINT NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    price NUMERIC(12,2) NOT NULL CHECK (price > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Складские остатки (1:1 с товаром)
CREATE TABLE stock (
    product_id BIGINT PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Корзины (у пользователя не более одной)
CREATE TABLE carts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Позиции корзины (ассоциативная таблица M:N корзина-товар)
CREATE TABLE cart_items (
    cart_id BIGINT NOT NULL REFERENCES carts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (cart_id, product_id)
);

-- 8. Адреса
CREATE TABLE addresses (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    city TEXT NOT NULL,
    street TEXT NOT NULL,
    house TEXT NOT NULL,
    apartment TEXT
);

-- 9. Заказы
CREATE TABLE orders (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'paid', 'shipped', 'delivered', 'cancelled')),
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. Позиции заказа (ассоциативная таблица M:N заказ-товар)
CREATE TABLE order_items (
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (order_id, product_id)
);

-- 11. Платежи (у заказа не более одного)
CREATE TABLE payments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    paid_at TIMESTAMPTZ,
    CONSTRAINT chk_paid_has_date CHECK (status <> 'paid' OR paid_at IS NOT NULL)
);

-- 12. Отзывы (один отзыв пользователя на товар)
CREATE TABLE reviews (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    score INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_review_user_product UNIQUE (user_id, product_id)
);

-- 13. Доставки (у заказа не более одной)
CREATE TABLE deliveries (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE,
    address_id BIGINT NOT NULL REFERENCES addresses(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    delivery_status TEXT NOT NULL DEFAULT 'processing' CHECK (delivery_status IN ('processing', 'in_transit', 'delivered', 'returned')),
    delivery_date TIMESTAMPTZ
);