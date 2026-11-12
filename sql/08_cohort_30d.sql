-- ============================================================
-- 首单后 30 天内复购率
-- 口径：首单 = 用户最早的支付订单；30 天内复购 = 首单后 1~30 天
--       还有支付订单（不含首单当天）；分母 = 有支付订单的用户数。
-- ============================================================

WITH first_order AS (
  SELECT user_id, MIN(order_date) AS first_date
  FROM v_orders_clean
  WHERE status = 'paid'
  GROUP BY user_id
),
later AS (
  SELECT f.user_id,
         MAX(CASE WHEN DATEDIFF(o.order_date, f.first_date) BETWEEN 1 AND 30
                  THEN 1 ELSE 0 END) AS repeat_30d
  FROM first_order f
  LEFT JOIN v_orders_clean o
         ON o.user_id = f.user_id
        AND o.status = 'paid'
        AND o.order_date > f.first_date
  GROUP BY f.user_id
)
SELECT COUNT(*)                     AS users_with_first_order,
       SUM(repeat_30d)              AS repeat_30d_users,
       ROUND(SUM(repeat_30d) / COUNT(*), 4) AS repeat_rate_30d
FROM later;
