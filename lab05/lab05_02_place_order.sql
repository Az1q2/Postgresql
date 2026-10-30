CREATE OR REPLACE FUNCTION place_order(
    p_user_id BIGINT,
    p_product_id BIGINT,
    p_quantity INT
)
RETURNS BIGINT AS $$
DECLARE
    v_order_id BIGINT;
    v_unit_price NUMERIC(12,2);
    v_current_stock INT;
    v_total NUMERIC(12,2);
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество товара должно быть больше нуля (передано: %)', p_quantity;
    END IF;

    SELECT price INTO v_unit_price
    FROM products
    WHERE id = p_product_id;

    IF v_unit_price IS NULL THEN
        RAISE EXCEPTION 'Товар с id=% не найден', p_product_id;
    END IF;

    SELECT quantity INTO v_current_stock
    FROM stock
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF v_current_stock IS NULL OR v_current_stock < p_quantity THEN
        RAISE EXCEPTION 'Недостаточно товара на складе (id=%). Доступно: %, запрошено: %',
            p_product_id, COALESCE(v_current_stock, 0), p_quantity;
    END IF;

    v_total := v_unit_price * p_quantity;

    INSERT INTO orders (user_id, status, total_amount)
    VALUES (p_user_id, 'new', v_total)
    RETURNING id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_unit_price);

    UPDATE stock
    SET quantity = quantity - p_quantity,
        updated_at = now()
    WHERE product_id = p_product_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

-- 1: Успешно
SELECT place_order(10, 495, 2);

-- Проверка после успешного
SELECT product_id, quantity FROM stock WHERE product_id = 495;

-- 2: Ошибка при нехватке товара (вызовет RAISE EXCEPTION и откат)
SELECT place_order(10, 495, 999999);

-- Проверка после ошибки
SELECT product_id, quantity FROM stock WHERE product_id = 495;
