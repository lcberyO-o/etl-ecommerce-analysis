-- ============================================================
-- 每个品类 GMV Top3 商品
-- 口径：商品 GMV = SUM(quantity * unit_price)，只统计支付订单；
--       用 RANK() 排名，并列时占用同一名次。
-- ============================================================

WITH item_gmv AS (
  SELECT p.category,
         p.product_id,
         SUM(oi.quantity * oi.unit_price) AS gmv
  FROM order_items oi
  JOIN products p          ON p.product_id = oi.product_id
  JOIN v_orders_clean v    ON v.order_id = oi.order_id AND v.status = 'paid'
  WHERE oi.quantity > 0
    AND oi.unit_price IS NOT NULL
  GROUP BY p.category, p.product_id
),
ranked AS (
  SELECT category, product_id, gmv,
         RANK() OVER (PARTITION BY category ORDER BY gmv DESC) AS rk
  FROM item_gmv
)
SELECT category, product_id, ROUND(gmv, 2) AS gmv, rk
FROM ranked
WHERE rk <= 3
ORDER BY category, rk;
