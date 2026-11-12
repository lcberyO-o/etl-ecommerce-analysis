CREATE OR REPLACE VIEW v_orders_clean AS
WITH dedup AS (
  SELECT o.*,
         ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY o.order_date) AS rn
  FROM orders o
),
valid AS (
  SELECT *
  FROM dedup
  WHERE rn = 1
    AND user_id IS NOT NULL
    AND status IS NOT NULL
    AND order_date BETWEEN '2025-01-01' AND '2026-10-31'
    AND channel_id IN (1, 2, 3, 4, 5, 6)
),
item_amt AS (
  SELECT order_id,
         SUM(quantity * unit_price) AS calc_amount
  FROM order_items
  WHERE quantity > 0
    AND unit_price IS NOT NULL
  GROUP BY order_id
),
item_cat AS (
  SELECT oi.order_id,
         p.category,
         SUM(oi.quantity * oi.unit_price) AS amt,
         ROW_NUMBER() OVER (
           PARTITION BY oi.order_id
           ORDER BY SUM(oi.quantity * oi.unit_price) DESC
         ) AS rn
  FROM order_items oi
  JOIN products p ON oi.product_id = p.product_id
  WHERE oi.quantity > 0
    AND oi.unit_price IS NOT NULL
  GROUP BY oi.order_id, p.category
)
SELECT v.order_id,
       v.user_id,
       v.order_date,
       v.channel_id,
       c.channel_name,
       ic.category AS main_category,
       COALESCE(a.calc_amount, v.total_amount) AS total_amount,
       v.status
FROM valid v
LEFT JOIN channels c   ON v.channel_id = c.channel_id
LEFT JOIN item_amt a   ON v.order_id = a.order_id
LEFT JOIN item_cat ic  ON v.order_id = ic.order_id AND ic.rn = 1
WHERE COALESCE(a.calc_amount, v.total_amount) > 0;