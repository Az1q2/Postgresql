ALTER TABLE products ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT NULL;

UPDATE products p
SET rating = sub.avg_score
FROM (
    SELECT product_id, ROUND(AVG(score)::numeric, 2) AS avg_score
    FROM reviews
    GROUP BY product_id
) sub
WHERE p.id = sub.product_id;

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

-- до (NULL)
SELECT id, title, rating FROM products WHERE id = 2;

-- Оценка 5
INSERT INTO reviews (user_id, product_id, score, comment)
VALUES (1, 2, 5, 'Отличный ноутбук!');

-- Стал 5
SELECT id, title, rating FROM products WHERE id = 2;

-- Оценка 3
INSERT INTO reviews (user_id, product_id, score, comment)
VALUES (2, 2, 3, 'Обычный ноутбук');

-- AVG 4
SELECT id, title, rating FROM products WHERE id = 2;

-- Пользователь 2 исправил на 5
UPDATE reviews
SET score = 5
WHERE user_id = 2 AND product_id = 2;

-- Снова 5
SELECT id, title, rating FROM products WHERE id = 2;
