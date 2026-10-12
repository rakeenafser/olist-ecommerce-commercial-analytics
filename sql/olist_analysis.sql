-- ============================================================
-- OLIST E-COMMERCE COMMERCIAL ANALYTICS
-- SQL Analysis using DuckDB
--
-- Focus:
-- Sales performance
-- Product/category performance
-- Seller performance
-- Customer behaviour
-- Delivery performance
-- Customer reviews
-- Power BI analytical views
-- ============================================================


-- ============================================================
-- 1. ORDER OVERVIEW
-- ============================================================

-- Total number of orders
SELECT
    COUNT(*) AS total_orders
FROM orders;


-- Orders by status
SELECT
    order_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- ============================================================
-- 2. PAYMENT AND ORDER VALUE VALIDATION
-- ============================================================

-- Total item value
SELECT
    ROUND(SUM(price), 2) AS total_item_value
FROM order_items;


-- Total recorded payment value
SELECT
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM payments;


-- Compare order-level item + freight value with payment value
WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_plus_freight
    FROM order_items
    GROUP BY order_id
),

payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value
    FROM payments
    GROUP BY order_id
)

SELECT
    COUNT(*) AS matched_orders,
    ROUND(
        AVG(ABS(i.item_plus_freight - p.total_payment_value)),
        2
    ) AS avg_difference,
    ROUND(
        MAX(ABS(i.item_plus_freight - p.total_payment_value)),
        2
    ) AS max_difference
FROM item_totals AS i
JOIN payment_totals AS p
    ON i.order_id = p.order_id;


-- ============================================================
-- 3. MONTHLY COMMERCIAL PERFORMANCE
-- ============================================================

-- Delivered payment value by month
WITH payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS order_payment_value
    FROM payments
    GROUP BY order_id
)

SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    ) AS order_month,

    ROUND(
        SUM(p.order_payment_value),
        2
    ) AS delivered_payment_value

FROM orders AS o
JOIN payment_totals AS p
    ON o.order_id = p.order_id

WHERE o.order_status = 'delivered'

GROUP BY order_month
ORDER BY order_month;


-- Month-over-month delivered payment growth
-- Analysis begins in 2017 because 2016 contains sparse/incomplete months.

WITH payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS order_payment_value
    FROM payments
    GROUP BY order_id
),

monthly_payments AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        ) AS order_month,

        SUM(p.order_payment_value) AS delivered_payment_value

    FROM orders AS o
    JOIN payment_totals AS p
        ON o.order_id = p.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'

    GROUP BY order_month
),

monthly_with_previous AS (
    SELECT
        order_month,
        delivered_payment_value,

        LAG(delivered_payment_value)
        OVER (ORDER BY order_month) AS previous_month_value

    FROM monthly_payments
)

SELECT
    order_month,

    ROUND(
        delivered_payment_value,
        2
    ) AS delivered_payment_value,

    ROUND(
        (
            delivered_payment_value
            - previous_month_value
        )
        * 100.0
        / previous_month_value,
        2
    ) AS month_over_month_growth_pct

FROM monthly_with_previous
ORDER BY order_month;


-- ============================================================
-- 4. PRODUCT CATEGORY PERFORMANCE
-- ============================================================

SELECT
    ct.product_category_name_english AS category,

    COUNT(*) AS items_sold,

    COUNT(
        DISTINCT oi.product_id
    ) AS unique_products,

    ROUND(
        COUNT(*) * 1.0
        / COUNT(DISTINCT oi.product_id),
        2
    ) AS items_per_product,

    ROUND(
        SUM(oi.price),
        2
    ) AS total_item_value,

    ROUND(
        AVG(oi.price),
        2
    ) AS average_item_price

FROM order_items AS oi

JOIN products AS p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation AS ct
    ON p.product_category_name
       = ct.product_category_name

GROUP BY category

ORDER BY total_item_value DESC;


-- ============================================================
-- 5. TOP INDIVIDUAL PRODUCTS
-- ============================================================

-- Best-selling products by item volume
SELECT
    oi.product_id,

    ct.product_category_name_english AS category,

    COUNT(*) AS times_sold,

    ROUND(
        SUM(oi.price),
        2
    ) AS total_item_value,

    ROUND(
        AVG(oi.price),
        2
    ) AS average_item_price

FROM order_items AS oi

JOIN products AS p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation AS ct
    ON p.product_category_name
       = ct.product_category_name

GROUP BY
    oi.product_id,
    category

ORDER BY times_sold DESC
LIMIT 15;


-- Highest-value products
SELECT
    oi.product_id,

    ct.product_category_name_english AS category,

    COUNT(*) AS times_sold,

    ROUND(
        SUM(oi.price),
        2
    ) AS total_item_value,

    ROUND(
        AVG(oi.price),
        2
    ) AS average_item_price

FROM order_items AS oi

JOIN products AS p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation AS ct
    ON p.product_category_name
       = ct.product_category_name

GROUP BY
    oi.product_id,
    category

ORDER BY total_item_value DESC
LIMIT 15;


-- ============================================================
-- 6. SELLER PERFORMANCE
-- ============================================================

SELECT
    oi.seller_id,
    s.seller_city,
    s.seller_state,

    COUNT(*) AS items_sold,

    COUNT(
        DISTINCT oi.order_id
    ) AS orders_served,

    ROUND(
        SUM(oi.price),
        2
    ) AS total_item_value,

    ROUND(
        AVG(oi.price),
        2
    ) AS average_item_price

FROM order_items AS oi

JOIN sellers AS s
    ON oi.seller_id = s.seller_id

GROUP BY
    oi.seller_id,
    s.seller_city,
    s.seller_state

ORDER BY total_item_value DESC
LIMIT 15;


-- Seller performance by state
SELECT
    s.seller_state,

    COUNT(
        DISTINCT oi.seller_id
    ) AS unique_sellers,

    COUNT(*) AS items_sold,

    COUNT(
        DISTINCT oi.order_id
    ) AS orders_served,

    ROUND(
        SUM(oi.price),
        2
    ) AS total_item_value,

    ROUND(
        AVG(oi.price),
        2
    ) AS average_item_price

FROM order_items AS oi

JOIN sellers AS s
    ON oi.seller_id = s.seller_id

GROUP BY s.seller_state

ORDER BY total_item_value DESC;


-- ============================================================
-- 7. MULTI-SELLER ORDERS
-- ============================================================

-- Orders containing products from more than one seller
WITH sellers_per_order AS (
    SELECT
        order_id,
        COUNT(
            DISTINCT seller_id
        ) AS number_of_sellers

    FROM order_items

    GROUP BY order_id
)

SELECT
    COUNT(*) AS multi_seller_orders
FROM sellers_per_order
WHERE number_of_sellers > 1;


-- ============================================================
-- 8. CUSTOMER REPEAT PURCHASE BEHAVIOUR
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,

        COUNT(
            DISTINCT o.order_id
        ) AS number_of_orders

    FROM customers AS c

    JOIN orders AS o
        ON c.customer_id = o.customer_id

    GROUP BY c.customer_unique_id
)

SELECT
    number_of_orders,
    COUNT(*) AS number_of_customers

FROM customer_orders

GROUP BY number_of_orders
ORDER BY number_of_orders;


-- ============================================================
-- 9. CUSTOMER GEOGRAPHY
-- ============================================================

WITH state_customers AS (
    SELECT
        customer_state,

        COUNT(
            DISTINCT customer_unique_id
        ) AS unique_customers

    FROM customers

    GROUP BY customer_state
)

SELECT
    customer_state,
    unique_customers,

    ROUND(
        unique_customers * 100.0
        / SUM(unique_customers) OVER (),
        2
    ) AS customer_share_pct

FROM state_customers

ORDER BY unique_customers DESC;


-- ============================================================
-- 10. HIGHEST-VALUE CUSTOMERS
-- ============================================================

WITH payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS order_payment_value

    FROM payments

    GROUP BY order_id
)

SELECT
    c.customer_unique_id,

    COUNT(
        DISTINCT o.order_id
    ) AS number_of_orders,

    ROUND(
        SUM(p.order_payment_value),
        2
    ) AS total_customer_value,

    ROUND(
        AVG(p.order_payment_value),
        2
    ) AS average_order_value

FROM customers AS c

JOIN orders AS o
    ON c.customer_id = o.customer_id

JOIN payment_totals AS p
    ON o.order_id = p.order_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_unique_id

ORDER BY total_customer_value DESC
LIMIT 15;


-- ============================================================
-- 11. DELIVERY PERFORMANCE
-- ============================================================

SELECT
    ROUND(
        AVG(
            DATE_DIFF(
                'day',
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        ),
        2
    ) AS average_delivery_days,

    SUM(
        CASE
            WHEN order_delivered_customer_date
                 > order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    COUNT(*) AS delivered_orders,

    ROUND(
        SUM(
            CASE
                WHEN order_delivered_customer_date
                     > order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        )
        * 100.0
        / COUNT(*),
        2
    ) AS late_delivery_pct

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;


-- ============================================================
-- 12. DELIVERY PERFORMANCE VS CUSTOMER REVIEWS
-- ============================================================

SELECT
    CASE
        WHEN o.order_delivered_customer_date
             > o.order_estimated_delivery_date
        THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,

    COUNT(
        DISTINCT o.order_id
    ) AS orders,

    ROUND(
        AVG(r.review_score),
        2
    ) AS average_review_score

FROM orders AS o

JOIN reviews AS r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY delivery_status;


-- ============================================================
-- 13. REVIEW SCORE DISTRIBUTION
-- ============================================================

SELECT
    review_score,

    COUNT(*) AS number_of_reviews,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS review_share_pct

FROM reviews

GROUP BY review_score

ORDER BY review_score;


-- ============================================================
-- 14. POWER BI ORDER-LEVEL VIEW
-- Grain: one row per order
-- ============================================================

CREATE OR REPLACE VIEW order_summary AS

WITH payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value
    FROM payments
    GROUP BY order_id
),

item_totals AS (
    SELECT
        order_id,
        SUM(price) AS item_value,
        SUM(freight_value) AS freight_value,
        COUNT(*) AS items_sold
    FROM order_items
    GROUP BY order_id
),

review_totals AS (
    SELECT
        order_id,
        AVG(review_score) AS review_score
    FROM reviews
    GROUP BY order_id
)

SELECT
    o.order_id,

    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    i.items_sold,
    i.item_value,
    i.freight_value,

    p.total_payment_value,

    DATE_DIFF(
        'day',
        o.order_purchase_timestamp,
        o.order_delivered_customer_date
    ) AS delivery_days,

    CASE
        WHEN o.order_delivered_customer_date
             > o.order_estimated_delivery_date
        THEN 'Late'

        WHEN o.order_delivered_customer_date IS NOT NULL
        THEN 'On Time'

        ELSE NULL
    END AS delivery_status,

    r.review_score

FROM orders AS o

LEFT JOIN customers AS c
    ON o.customer_id = c.customer_id

LEFT JOIN item_totals AS i
    ON o.order_id = i.order_id

LEFT JOIN payment_totals AS p
    ON o.order_id = p.order_id

LEFT JOIN review_totals AS r
    ON o.order_id = r.order_id;


-- ============================================================
-- 15. POWER BI ITEM-LEVEL VIEW
-- Grain: one row per order item
-- ============================================================

CREATE OR REPLACE VIEW sales_detail AS

SELECT
    oi.order_id,
    oi.order_item_id,

    o.order_purchase_timestamp,
    o.order_status,

    oi.product_id,

    ct.product_category_name_english AS category,

    oi.seller_id,
    s.seller_city,
    s.seller_state,

    oi.price,
    oi.freight_value

FROM order_items AS oi

JOIN orders AS o
    ON oi.order_id = o.order_id

LEFT JOIN products AS p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation AS ct
    ON p.product_category_name
       = ct.product_category_name

LEFT JOIN sellers AS s
    ON oi.seller_id = s.seller_id;
