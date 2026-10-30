CREATE TABLE IF NOT EXISTS product_price_audit (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    old_price NUMERIC(12,2) NOT NULL,
    new_price NUMERIC(12,2) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION audit_product_price_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.price <> NEW.price THEN
        INSERT INTO product_price_audit (product_id, old_price, new_price, changed_at)
        VALUES (OLD.id, OLD.price, NEW.price, now());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_audit_product_price
AFTER UPDATE OF price ON products
FOR EACH ROW
EXECUTE FUNCTION audit_product_price_change();

-- Товар 1
SELECT id, price FROM products WHERE id = 1;

-- Изменение цены товара 1
UPDATE products
SET price = price + 500
WHERE id = 1;

-- Проверка записи 1
SELECT * FROM product_price_audit WHERE product_id = 1;

-- Изменение другого поля
UPDATE products
SET description = 'Обновлённое описание'
WHERE id = 1;

-- Проверка записи 2
SELECT * FROM product_price_audit WHERE product_id = 1;
