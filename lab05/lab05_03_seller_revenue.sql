CREATE OR REPLACE FUNCTION get_seller_revenue(
    p_seller_id BIGINT,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
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

-- OAL
SELECT get_seller_revenue(1);

-- С 2026-01-01 до now
SELECT get_seller_revenue(1, '2026-01-01', now());

-- При несуществующем продавце
SELECT get_seller_revenue(999999);
