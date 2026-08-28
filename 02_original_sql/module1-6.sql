USE commerce_practice; 

SELECT 
    p.category AS `商品类目`,
    SUM(oi.quantity * oi.unit_price_usd) AS `总营收`,
    SUM(oi.quantity * p.cost_usd) AS `总成本`,
    SUM(oi.quantity * oi.unit_price_usd) - SUM(oi.quantity * p.cost_usd) AS `毛利润`,
    (SUM(oi.quantity * oi.unit_price_usd) - SUM(oi.quantity * p.cost_usd)) / SUM(oi.quantity * oi.unit_price_usd) AS `毛利率`
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id  -- 既然你确认了字段名，这里改回 product_id
GROUP BY p.category
ORDER BY `毛利润` DESC;

WITH funnel_base AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN session_id END) AS view_uv,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN session_id END) AS cart_uv,
        COUNT(DISTINCT CASE WHEN event_type = 'checkout' THEN session_id END) AS checkout_uv,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN session_id END) AS purchase_uv
    FROM events
)
SELECT 
    view_uv AS `浏览人数`,
    cart_uv AS `加购人数`,
    checkout_uv AS `结算人数`,
    purchase_uv AS `支付人数`,
    
    ROUND(cart_uv / view_uv, 4) AS view_to_cart_rate,
    ROUND(checkout_uv / cart_uv, 4) AS cart_to_checkout_rate,
    ROUND(purchase_uv / checkout_uv, 4) AS checkout_to_purchase_rate,
    ROUND(purchase_uv / view_uv, 4) AS overall_conversion_rate
FROM funnel_base;


WITH user_first_order AS (
    -- 第一步：找出每个用户的“首单月份”（定义他属于哪个同期群）
    SELECT 
        customer_id,
        DATE_FORMAT(MIN(order_time), '%Y-%m-01') AS cohort_month
    FROM orders
    GROUP BY customer_id
),
user_activity AS (
    -- 第二步：提取所有订单的活跃月份
    SELECT 
        customer_id,
        DATE_FORMAT(order_time, '%Y-%m-01') AS activity_month
    FROM orders
),
cohort_size AS (
    -- 第三步：计算每个同期群的初始总人数 (Month 0)
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS total_users
    FROM user_first_order
    GROUP BY cohort_month
)
-- 第四步：计算相对月数差，并统计留存人数和留存率
SELECT 
    u.cohort_month AS `获取群组(Cohort)`,
    TIMESTAMPDIFF(MONTH, u.cohort_month, a.activity_month) AS `留存月份(Month_Index)`,
    c.total_users AS `该群组初始人数`,
    COUNT(DISTINCT a.customer_id) AS `留存活跃人数`,
    ROUND(COUNT(DISTINCT a.customer_id) / c.total_users, 4) AS `真实留存率(Retention_Rate)`
FROM user_first_order u
JOIN user_activity a ON u.customer_id = a.customer_id
JOIN cohort_size c ON u.cohort_month = c.cohort_month
WHERE TIMESTAMPDIFF(MONTH, u.cohort_month, a.activity_month) <= 12
GROUP BY u.cohort_month, `留存月份(Month_Index)`, c.total_users
ORDER BY u.cohort_month, `留存月份(Month_Index)`;


WITH review_base AS (
    SELECT 
        p.category,
        r.rating
    FROM reviews r
    JOIN products p ON r.product_id = p.product_id
)
SELECT 
    category AS `商品类目`,
    COUNT(rating) AS `总评价数`,
    ROUND(AVG(rating), 2) AS `平均评分`,
    SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END) AS `差评数`,
    ROUND(SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END) / COUNT(rating), 4) AS `差评率`
FROM review_base
GROUP BY category
HAVING COUNT(rating) > 50 
ORDER BY `差评率` DESC;


WITH user_rfm_base AS (
    -- 提取每个用户的最后购买日期、购买次数、总消费金额
    SELECT 
        o.customer_id,
        MAX(o.order_time) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.quantity * oi.unit_price_usd) AS monetary
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT 
    customer_id,
    -- R: 计算最近一次购买距离“数据集中最后一天”的天数
    DATEDIFF((SELECT MAX(order_time) FROM orders), last_purchase_date) AS recency_days,
    -- F: 购买频次
    frequency,
    -- M: 消费总额
    ROUND(monetary, 2) AS total_monetary
FROM user_rfm_base
ORDER BY total_monetary DESC;

SELECT 
    CASE 
        WHEN o.discount_pct > 0 THEN '使用了折扣 (Discounted)'
        ELSE '未使用折扣 (Full Price)'
    END AS discount_strategy,
    COUNT(DISTINCT o.order_id) AS `总订单数`,
    ROUND(AVG(oi.quantity * oi.unit_price_usd), 2) AS `平均客单价 (AOV)`,  
    -- 结合成本计算真实的平均单笔利润
    ROUND(AVG( (oi.quantity * oi.unit_price_usd) - (oi.quantity * p.cost_usd) ), 2) AS `平均单笔利润`,
    -- 毛利率对比
    ROUND( SUM((oi.quantity * oi.unit_price_usd) - (oi.quantity * p.cost_usd)) / SUM(oi.quantity * oi.unit_price_usd), 4) AS `整体毛利率`
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY discount_strategy;