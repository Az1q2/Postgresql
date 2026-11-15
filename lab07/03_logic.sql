CREATE OR REPLACE FUNCTION place_order(
    p_user_id    BIGINT,
    p_product_id BIGINT,
    p_quantity   INT
)
RETURNS BIGINT AS $$
DECLARE
    v_order_id      BIGINT;
    v_unit_price    NUMERIC(12,2);
    v_current_stock INT;
    v_total         NUMERIC(12,2);
BEGIN
    -- 1. Валидация входных параметров
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество товара должно быть больше нуля (передано: %)', p_quantity;
    END IF;

    -- 2. Получение текущей цены товара
    SELECT price INTO v_unit_price
    FROM products
    WHERE id = p_product_id;

    IF v_unit_price IS NULL THEN
        RAISE EXCEPTION 'Товар с id=% не найден', p_product_id;
    END IF;

    -- 3. Проверка остатка с блокировкой строки (FOR UPDATE исключает race condition)
    SELECT quantity INTO v_current_stock
    FROM stock
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF v_current_stock IS NULL OR v_current_stock < p_quantity THEN
        RAISE EXCEPTION 'Недостаточно товара на складе (id=%). Доступно: %, запрошено: %',
            p_product_id, COALESCE(v_current_stock, 0), p_quantity;
    END IF;

    v_total := v_unit_price * p_quantity;

    -- 4. Создание заказа
    INSERT INTO orders (user_id, status, total_amount)
    VALUES (p_user_id, 'new', v_total)
    RETURNING id INTO v_order_id;

    -- 5. Добавление позиции заказа
    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_unit_price);

    -- 6. Списание со склада
    UPDATE stock
    SET quantity = quantity - p_quantity,
        updated_at = now()
    WHERE product_id = p_product_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_seller_revenue(
    p_seller_id  BIGINT,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date   TIMESTAMPTZ DEFAULT NULL
)
RETURNS NUMERIC(12,2) AS $$
DECLARE
    v_seller_exists BOOLEAN;
    v_total_revenue NUMERIC(12,2) := 0;
BEGIN
    SELECT EXISTS (SELECT 1 FROM sellers WHERE id = p_seller_id)
    INTO v_seller_exists;

    IF NOT v_seller_exists THEN
        RAISE EXCEPTION 'Продавец с id=% не найден', p_seller_id;
    END IF;

    SELECT COALESCE(SUM(oi.quantity * oi.unit_price), 0.00)
    INTO v_total_revenue
    FROM order_items oi
    JOIN products p ON p.id = oi.product_id
    JOIN orders o ON o.id = oi.order_id
    WHERE p.seller_id = p_seller_id
      AND o.status <> 'cancelled'
      AND (p_start_date IS NULL OR o.created_at >= p_start_date)
      AND (p_end_date IS NULL OR o.created_at <= p_end_date);

    RETURN v_total_revenue;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION audit_product_price_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.price <> NEW.price THEN
        INSERT INTO product_price_audit (product_id, old_price, new_price, changed_at, changed_by)
        VALUES (OLD.id, OLD.price, NEW.price, now(), CURRENT_USER);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_audit_product_price
AFTER UPDATE OF price ON products
FOR EACH ROW
EXECUTE FUNCTION audit_product_price_change();


CREATE OR REPLACE FUNCTION refresh_product_rating()
RETURNS TRIGGER AS $$
DECLARE
    v_product_id BIGINT;
BEGIN
    v_product_id := COALESCE(NEW.product_id, OLD.product_id);

    UPDATE products
    SET rating = (
        SELECT ROUND(AVG(score)::numeric, 2)
        FROM reviews
        WHERE product_id = v_product_id
    )
    WHERE id = v_product_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_refresh_product_rating
AFTER INSERT OR UPDATE OF score OR DELETE ON reviews
FOR EACH ROW
EXECUTE FUNCTION refresh_product_rating();


-- Проверка 1: Оформление заказа через place_order
SELECT place_order(10, 1, 2) AS created_order_id;

-- Проверка 2: Расчёт выручки продавца №1
SELECT get_seller_revenue(1) AS seller_1_total_revenue;

-- Проверка 3: Проверка триггера аудита цен (обновляем цену товара 1)
UPDATE products SET price = price + 500 WHERE id = 1;
SELECT * FROM product_price_audit WHERE product_id = 1;

-- Проверка 4: Проверка триггера рейтинга (добавляем новый отзыв)
INSERT INTO reviews (user_id, product_id, score, comment)
VALUES (15, 10, 5, 'Отличный ноутбук для учёбы!')
ON CONFLICT (user_id, product_id) DO UPDATE SET score = 5;

SELECT id, title, rating FROM products WHERE id = 10;
