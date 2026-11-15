-- 0. Очистка существующих объектов в порядке обратной зависимости
DROP TABLE IF EXISTS product_price_audit CASCADE;
DROP TABLE IF EXISTS deliveries CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS carts CASCADE;
DROP TABLE IF EXISTS stock CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 1. Пользователи (покупатели, продавцы, администраторы)
CREATE TABLE users (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name  TEXT NOT NULL,
    email      TEXT NOT NULL UNIQUE,
    role       TEXT NOT NULL DEFAULT 'buyer' CHECK (role IN ('buyer', 'seller', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Магазины-продавцы (1:1 или 1:0..1 с учётной записью пользователя)
CREATE TABLE sellers (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    store_name  TEXT NOT NULL UNIQUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Категории товаров (иерархическая структура через самоссылку parent_id)
CREATE TABLE categories (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id BIGINT REFERENCES categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    name      TEXT NOT NULL UNIQUE,
    CONSTRAINT chk_category_not_self_parent
        CHECK (parent_id IS NULL OR parent_id <> id)
);

-- 4. Карточки товаров (включая JSONB-характеристики и денормализованный рейтинг)
CREATE TABLE products (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id   BIGINT NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    price       NUMERIC(12,2) NOT NULL CHECK (price > 0),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    attributes  JSONB,
    rating      NUMERIC(3,2) CHECK (rating IS NULL OR (rating >= 1.00 AND rating <= 5.00)),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Складские остатки (1:1 с товаром)
CREATE TABLE stock (
    product_id BIGINT PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    quantity   INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Корзины покупателей (1:1 с пользователем)
CREATE TABLE carts (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Позиции в корзине (составной первичный ключ)
CREATE TABLE cart_items (
    cart_id    BIGINT NOT NULL REFERENCES carts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    quantity   INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (cart_id, product_id)
);

-- 8. Адреса доставки пользователей (1:N)
CREATE TABLE addresses (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    city       TEXT NOT NULL,
    street     TEXT NOT NULL,
    house      TEXT NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. Заказы покупателей
CREATE TABLE orders (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    status       TEXT NOT NULL DEFAULT 'new'
                 CHECK (status IN ('new', 'paid', 'delivering', 'completed', 'cancelled')),
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. Позиции заказа (ассоциативная таблица «многие-ко-многим»)
CREATE TABLE order_items (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id   BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    quantity   INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),
    CONSTRAINT uq_order_product UNIQUE (order_id, product_id)
);

-- 11. Платежи (1:1 с заказом)
CREATE TABLE payments (
    id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    amount   NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    status   TEXT NOT NULL DEFAULT 'pending'
             CHECK (status IN ('pending', 'completed', 'failed')),
    paid_at  TIMESTAMPTZ
);

-- 12. Отзывы покупателей на товары (один отзыв от пользователя на товар)
CREATE TABLE reviews (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    score      INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment    TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_product_review UNIQUE (user_id, product_id)
);

-- 13. Доставка заказов (1:1 с заказом)
CREATE TABLE deliveries (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    address_id      BIGINT NOT NULL REFERENCES addresses(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    delivery_status TEXT NOT NULL DEFAULT 'processing'
                    CHECK (delivery_status IN ('processing', 'in_transit', 'delivered', 'failed')),
    tracking_code   TEXT,
    shipped_at      TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ
);

-- 14. Таблица аудита истории изменений цен товаров
CREATE TABLE product_price_audit (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL,
    old_price  NUMERIC(12,2) NOT NULL,
    new_price  NUMERIC(12,2) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    changed_by TEXT NOT NULL DEFAULT CURRENT_USER
);
