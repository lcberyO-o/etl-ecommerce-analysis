-- ============================================================
-- 各渠道复购率
-- 口径：按「用户注册渠道」（users.channel_id）归因，而不是下单渠道；
--       复购用户 = 支付订单数 >= 2 的用户；
--       复购率 = 复购用户数 / 该渠道下有支付订单的用户数。
-- ============================================================

WITH user_paid AS (
  SELECT u.user_id,
         u.channel_id,
         COUNT(DISTINCT o.order_id) AS paid_orders
  FROM users u
  JOIN v_orders_clean o
    ON o.user_id = u.user_id
   AND o.status = 'paid'
  GROUP BY u.user_id, u.channel_id
)
SELECT c.channel_name,
       COUNT(*)                                        AS buyers,
       SUM(up.paid_orders >= 2)                        AS repeat_buyers,
       ROUND(SUM(up.paid_orders >= 2) / COUNT(*), 4)    AS repeat_rate
FROM user_paid up
JOIN channels c ON c.channel_id = up.channel_id
GROUP BY c.channel_name
ORDER BY repeat_rate DESC;
