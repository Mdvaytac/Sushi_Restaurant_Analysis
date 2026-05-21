--1. Total Revenue and Average Order Value by Channel
--Calculate the total revenue, number of orders, and average revenue for each channel (dine-in, takeaway, delivery).

SELECT channel,
  COUNT(*) AS order_count,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(AVG(revenue), 2) AS avg_revenue
FROM sushi_orders
GROUP BY channel
ORDER BY total_revenue DESC;

--2. Weekend vs Weekday Revenue Comparison
--Using the is_weekend column, compare revenue, profit, and average values between weekends and weekdays.

SELECT 
  CASE WHEN is_weekend = 1 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
  COUNT(*) AS day_count,
  ROUND(SUM(gross_revenue), 2) AS total_revenue,
  ROUND(AVG(covers), 1) AS avg_covers,
  ROUND(SUM(operating_profit), 2) AS total_op_profit
FROM sushi_daily_pnl
GROUP BY is_weekend;

--3. Top Ordering Customers by Customer Segment
--Calculate the number of orders, total revenue, and average rating for each customer segment.

SELECT customer_segment,
  COUNT(*) AS order_count,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(AVG(rating), 2) AS avg_rating,
  ROUND(AVG(party_size), 1) AS avg_party_size
FROM sushi_orders
WHERE rating IS NOT NULL
GROUP BY customer_segment
ORDER BY order_count DESC;

--4. Best-Selling Item Categories by Month
--Find which category (e.g., nigiri, rolls) sold the most each month and show the monthly trend.

SELECT 
  strftime('%Y-%m', date) AS month,
  category,
  COUNT(*) AS item_count,
  ROUND(SUM(gross_profit), 2) AS total_profit
FROM sushi_order_items
GROUP BY month, category
ORDER BY month, item_count DESC;

--5. Top 10 Most Expensive Menu Items
--Show the top 10 most expensive items based on unit_price, along with their category and average profit margin.

SELECT item, category,
  ROUND(AVG(unit_price), 2) AS avg_price,
  ROUND(AVG(gross_profit), 2) AS avg_profit,
  ROUND(AVG(gross_profit / unit_price) * 100, 1) AS profit_margin_pct,
  COUNT(*) AS times_ordered
FROM sushi_order_items
GROUP BY item, category
ORDER BY avg_price DESC
LIMIT 10;

--6. Analysis of Orders with Delivery Fees
--Analyze only orders where delivery_fee > 0: average revenue, tip, rating, and channel.

SELECT channel,
  COUNT(*) AS delivery_orders,
  ROUND(AVG(delivery_fee), 2) AS avg_delivery_fee,
  ROUND(AVG(revenue), 2) AS avg_revenue,
  ROUND(AVG(tip), 2) AS avg_tip,
  ROUND(AVG(rating), 2) AS avg_rating
FROM sushi_orders
WHERE delivery_fee > 0
GROUP BY channel
ORDER BY delivery_orders DESC;

--7. Impact of Holidays on Revenue
--Compare revenue, customer count, and profit between holidays (is_holiday=1) and regular days.

SELECT 
  CASE WHEN is_holiday = 1 THEN 'Holiday' ELSE 'Regular Day' END AS day_type,
  COUNT(*) AS days_count,
  ROUND(AVG(gross_revenue), 2) AS avg_revenue,
  ROUND(AVG(covers), 1) AS avg_covers,
  ROUND(AVG(gp_margin_pct), 2) AS avg_gp_margin
FROM sushi_daily_pnl
GROUP BY is_holiday;

--8. Total Spending by Customer (INNER JOIN)
--Join sushi_customers and sushi_orders tables to show each customer’s total spending and order count.

SELECT c.customer_id, c.segment, c.is_local,
  COUNT(o.order_id) AS order_count,
  ROUND(SUM(o.revenue), 2) AS total_spent,
  ROUND(AVG(o.rating), 2) AS avg_rating
FROM sushi_customers c
INNER JOIN sushi_orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.segment, c.is_local
ORDER BY total_spent DESC
LIMIT 15;

--9. Monthly Revenue Growth Compared to Previous Month
--Using the LAG() function, compare each month’s revenue with the previous month and calculate the growth percentage.

WITH monthly AS (
  SELECT year, month,
    ROUND(SUM(gross_revenue), 2) AS total_revenue
  FROM sushi_daily_pnl
  GROUP BY year, month
)
SELECT year, month, total_revenue,
  LAG(total_revenue) OVER (ORDER BY year, month) AS prev_month_revenue,
  ROUND((total_revenue - LAG(total_revenue) OVER (ORDER BY year, month))
    / LAG(total_revenue) OVER (ORDER BY year, month) * 100, 2) AS growth_pct
FROM monthly
ORDER BY year, month;

--10. Best Customer in Each Segment
--Write a query to find the highest-spending customer in each customer segment (use a correlated subquery).

SELECT o1.customer_segment, o1.customer_id,
  ROUND(SUM(o1.revenue), 2) AS total_spent
FROM sushi_orders o1
GROUP BY o1.customer_segment, o1.customer_id
HAVING total_spent = (
  SELECT MAX(sub.total)
  FROM (
    SELECT customer_id, customer_segment,
      SUM(revenue) AS total
    FROM sushi_orders
    WHERE customer_segment = o1.customer_segment
    GROUP BY customer_id
  ) sub
)
ORDER BY total_spent DESC;


--11. Orders Generating 2x More Revenue Than Average
--Identify orders that generate more than twice the overall average revenue and also have a high rating.

WITH avg_revenue AS (
  SELECT AVG(revenue) AS avg_rev FROM sushi_orders
)
SELECT o.order_id, o.date, o.channel, o.customer_segment,
  o.revenue, o.rating, o.party_size,
  ROUND(o.revenue / ar.avg_rev, 2) AS times_above_avg
FROM sushi_orders o
CROSS JOIN avg_revenue ar
WHERE o.revenue > 2 * ar.avg_rev
  AND o.rating >= 4
ORDER BY o.revenue DESC;

--12. Combining Menu Items with Order Details
--Join sushi_order_items and sushi_orders tables to show which category sells the most in each channel and its total profit.

SELECT o.channel, oi.category,
  COUNT(*) AS items_sold,
  ROUND(SUM(oi.unit_price), 2) AS total_revenue,
  ROUND(SUM(oi.gross_profit), 2) AS total_profit,
  ROUND(SUM(oi.gross_profit) / SUM(oi.unit_price) * 100, 1) AS profit_margin_pct
FROM sushi_order_items oi
INNER JOIN sushi_orders o ON oi.order_id = o.order_id
GROUP BY o.channel, oi.category
ORDER BY o.channel, total_profit DESC;

--13. Customer Retention Analysis — First and Last Order
--Calculate each customer’s first and last order date, the number of days between them, and total order count. Show only customers with 5+ orders.

SELECT customer_id,
  MIN(date_) AS first_order,
  MAX(date_) AS last_order,
  ROUND(JULIANDAY(MAX(date_)) - JULIANDAY(MIN(date_))) AS days_as_customer,
  COUNT(*) AS total_orders,
  ROUND(SUM(revenue), 2) AS total_spent,
  ROUND(AVG(rating), 2) AS avg_rating
FROM sushi_orders
GROUP BY customer_id
HAVING COUNT(*) >= 5
ORDER BY days_as_customer DESC
LIMIT 20;

--14. Share of Quarterly Revenue (NTILE + Percent)
--Calculate how much each order contributes to the total revenue of its quarter. Use NTILE(4) to determine revenue quartiles.

SELECT order_id, date_, quarter, revenue,
  ROUND(SUM(revenue) OVER (PARTITION BY year, quarter), 2) AS quarter_total,
  ROUND(revenue / SUM(revenue) OVER (PARTITION BY year, quarter) * 100, 3) AS pct_of_quarter,
  NTILE(4) OVER (PARTITION BY year, quarter ORDER BY revenue) AS revenue_quartile
FROM sushi_orders
ORDER BY year, quarter, revenue DESC;

--15. Analysis of Customers Ordering Alcoholic Drinks
--Calculate the total number of orders, average spending, and average rating of customers where drinks_alcohol = 1.

SELECT c.drinks_alcohol,
  COUNT(DISTINCT c.customer_id) AS customer_count,
  COUNT(o.order_id) AS order_count,
  ROUND(AVG(o.revenue),2) AS avg_revenue,
  ROUND(AVG(o.tip),2) AS avg_tip,
  ROUND(AVG(o.rating),2) AS avg_rating
FROM sushi_customers c
JOIN sushi_orders o ON c.customer_id = o.customer_id
GROUP BY c.drinks_alcohol;

--16. Share of Discounted Orders
--Calculate the number of orders with discount > 0, the total discount amount, and their share among all orders.

SELECT 
  COUNT(*) AS total_orders,
  SUM(CASE WHEN discount > 0 THEN 1 ELSE 0 END) AS discounted_orders,
  ROUND(SUM(CASE WHEN discount > 0 THEN 1.0 ELSE 0 END)/COUNT(*)*100,2) AS discount_rate_pct,
  ROUND(SUM(discount),2) AS total_discount_given,
  ROUND(AVG(CASE WHEN discount>0 THEN discount END),2) AS avg_discount
FROM sushi_orders;



------------------------------------------------------------------------------------------------



--1. Customer Distribution by Segment
--Calculate the number of customers in each segment, the local/tourist ratio, and the percentage of customers consuming alcohol.

SELECT segment,
  COUNT(*) AS customer_count,
  ROUND(sum(case when is_local="True" then 1 else 0 end)*100/ count(*),1) AS local_pct,
  ROUND(sum(case when drinks_alcohol="True" then 1 else 0 end)*100/ count(*),1) AS alcohol_pct,
  ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM sushi_customers),2) AS share_pct
FROM sushi_customers
GROUP BY segment
ORDER BY customer_count DESC;

--2. 3-Table Join — Customer + Order + Review
--Join sushi_customers, sushi_orders, and sushi_reviews to compare average review ratings and actual order ratings by segment.

SELECT c.segment,
  COUNT(DISTINCT o.order_id) AS order_count,
  ROUND(AVG(o.rating),5) AS avg_order_rating,
  ROUND(AVG(r.rating),5) AS avg_review_rating,
  ROUND(AVG(o.rating) - AVG(r.rating),2) AS rating_diff
FROM sushi_customers c
JOIN sushi_orders o ON c.customer_id = o.customer_id
JOIN sushi_reviews r ON o.order_id = r.order_id
WHERE o.rating IS NOT NULL AND r.rating IS NOT NULL
GROUP BY c.segment
ORDER BY avg_review_rating DESC;


WITH base AS (
SELECT c.field1 AS customer_id,
       c.field2 AS segment,
       o.field21 AS order_rating,
       r.field3 AS review_rating      
FROM sushi_customers c
LEFT JOIN sushi_orders o ON c.field1 = o.field9 
LEFT JOIN sushi_reviews r ON c.field1 = r.field1
)
SELECT segment,
       AVG(order_rating) AS avg_order_rating,
       AVG(review_rating) AS avg_review_rating,
       AVG(review_rating) - AVG(order_rating) AS rating_gap
FROM base
GROUP BY segment;

--3. Customer Activity After First Order
--Using a CTE, determine whether each customer placed another order within 30 days after their first order.

WITH first_orders AS (
  SELECT customer_id, MIN(date_) AS first_date
  FROM sushi_orders
  GROUP BY customer_id
),
returning_ AS (
  SELECT o.customer_id
  FROM sushi_orders o
  JOIN first_orders f ON o.customer_id = f.customer_id
  WHERE o.date_ > f.first_date
    AND JULIANDAY(o.date_) - JULIANDAY(f.first_date) <= 30
  GROUP BY o.customer_id
)
SELECT 
  COUNT(DISTINCT f.customer_id) AS total_customers,
  COUNT(DISTINCT r.customer_id) AS returned_in_30days,
  ROUND(COUNT(DISTINCT r.customer_id)*100.0/COUNT(DISTINCT f.customer_id),2) AS retention_rate_pct
FROM first_orders f
LEFT JOIN returning_ r ON f.customer_id = r.customer_id;


--4. Average Days Between Orders (LAG)
--Calculate the number of days between consecutive orders for each customer using LAG(), and determine the average return interval.

WITH order_gaps AS (
  SELECT customer_id, date_,
    LAG(date_) OVER (PARTITION BY customer_id ORDER BY date_) AS prev_date,
    JULIANDAY(date_) - JULIANDAY(
      LAG(date_) OVER (PARTITION BY customer_id ORDER BY date_)
    ) AS days_since_last
  FROM sushi_orders
)
SELECT customer_id,
  COUNT(*) AS total_orders,
  ROUND(AVG(days_since_last),1) AS avg_days_between_orders,
  ROUND(MIN(days_since_last),0) AS min_gap_days,
  ROUND(MAX(days_since_last),0) AS max_gap_days
FROM order_gaps
WHERE days_since_last IS NOT NULL
GROUP BY customer_id
HAVING COUNT(*) >= 3
ORDER BY avg_days_between_orders
LIMIT 20;


--5. Average Employee Tenure
--Calculate the number of days between hire date and termination date for each employee. Employees with NULL termination_date are still working.

SELECT role,
  COUNT(*) AS total_staff,
  SUM(CASE WHEN termination_date IS NULL THEN 1 ELSE 0 END) AS still_working,
  ROUND(AVG(
    JULIANDAY(COALESCE(termination_date,'2024-12-31')) - JULIANDAY(hire_date)
  ),0) AS avg_tenure_days,
  ROUND(AVG(
    JULIANDAY(COALESCE(termination_date,'2024-12-31')) - JULIANDAY(hire_date)
  )/365,1) AS avg_tenure_years
FROM sushi_staff
GROUP BY role
ORDER BY avg_tenure_days DESC;

--6. Share of Discounted Orders
--Calculate the number of orders with discount > 0, the total discount amount, and their share among all orders.

SELECT 
  COUNT(*) AS total_orders,
  SUM(CASE WHEN discount > 0 THEN 1 ELSE 0 END) AS discounted_orders,
  ROUND(SUM(CASE WHEN discount > 0 THEN 1.0 ELSE 0 END)/COUNT(*)*100,2) AS discount_rate_pct,
  ROUND(SUM(discount),2) AS total_discount_given,
  ROUND(AVG(CASE WHEN discount>0 THEN discount END),2) AS avg_discount
FROM sushi_orders;

--7. Top 3 Best-Selling Menu Items Each Year
--Extract the year using strftime and find the top 3 most ordered items for each year.

WITH item_counts AS (
  SELECT strftime('%Y', date) AS yr, item, category,
    COUNT(*) AS cnt,
    ROUND(SUM(gross_profit),2) AS total_gp
  FROM sushi_order_items
  GROUP BY yr, item
)
SELECT yr, item, category, cnt, total_gp
FROM item_counts ic
WHERE cnt >= (
  SELECT cnt FROM item_counts ic2
  WHERE ic2.yr = ic.yr
  ORDER BY cnt DESC LIMIT 1 OFFSET 2
)
ORDER BY yr, cnt DESC;



--8. 30-Day Moving Average of Daily Revenue
--Calculate the 30-day moving average revenue using a sliding window. Also show the deviation of the current day from the average.

SELECT date, gross_revenue,
  ROUND(AVG(gross_revenue) OVER (
    ORDER BY date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ),2) AS ma30,
  ROUND(gross_revenue - AVG(gross_revenue) OVER (
    ORDER BY date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ),2) AS deviation_from_ma30
FROM sushi_daily_pnl
ORDER BY date;

--9. 4-Table Join: Complete Order Profile
--Join sushi_orders, sushi_order_items, sushi_customers, and sushi_reviews to create a complete profile for each order.

SELECT o.order_id, o.date_, o.channel,
  c.segment, c.is_local,
  COUNT(oi.item) AS item_count,
  ROUND(SUM(oi.unit_price),2) AS items_total,
  o.revenue, o.tip, o.discount,
  r.rating AS review_rating
FROM sushi_orders o
JOIN sushi_customers c ON o.customer_id = c.customer_id
JOIN sushi_order_items oi ON o.order_id = oi.order_id
LEFT JOIN sushi_reviews r ON o.order_id = r.order_id
GROUP BY o.order_id, o.date_, o.channel,
  c.segment, c.is_local, o.revenue, o.tip, o.discount, r.rating
ORDER BY o.date_ DESC
LIMIT 20;


--10. Customers Placing 2+ Orders on the Same Day
--Find customers who placed 2 or more orders on the same date and show their total spending.

WITH multi_orders AS (
  SELECT customer_id, date_,
    COUNT(*) AS orders_that_day,
    ROUND(SUM(revenue),2) AS daily_spend
  FROM sushi_orders
  GROUP BY customer_id, date_
  HAVING COUNT(*) >= 2
)
SELECT customer_id,
  COUNT(*) AS days_with_multiple_orders,
  SUM(orders_that_day) AS total_multi_orders,
  ROUND(AVG(daily_spend),2) AS avg_daily_spend_on_those_days
FROM multi_orders
GROUP BY customer_id
ORDER BY days_with_multiple_orders DESC
LIMIT 15;


--11. Weekly Revenue Growth by Channel
--Calculate weekly revenue for each channel and use LAG() to show percentage growth compared to the previous week.

WITH weekly AS (
  SELECT channel,
    strftime('%Y', date_) AS yr,
    strftime('%W', date_) AS week_num,
    ROUND(SUM(revenue),2) AS weekly_rev
  FROM sushi_orders
  GROUP BY channel, yr, week_num
)
SELECT channel, yr, week_num, weekly_rev,
  LAG(weekly_rev) OVER (PARTITION BY channel ORDER BY yr, week_num) AS prev_week,
  ROUND((weekly_rev - LAG(weekly_rev) OVER (PARTITION BY channel ORDER BY yr, week_num))
    / LAG(weekly_rev) OVER (PARTITION BY channel ORDER BY yr, week_num) * 100, 2) AS wow_growth_pct
FROM weekly
ORDER BY channel, yr, week_num;

--12. Time Between Registration and First Order
--Calculate the number of days between sushi_customers.joined_date and the first order date. Identify customers who waited the longest before ordering.

WITH first_orders AS (
  SELECT customer_id, MIN(date_) AS first_order_date
  FROM sushi_orders
  GROUP BY customer_id
)
SELECT c.customer_id, c.segment, c.joined_date,
  f.first_order_date,
  ROUND(JULIANDAY(f.first_order_date) - JULIANDAY(c.joined_date), 0) AS days_to_first_order
FROM sushi_customers c
JOIN first_orders f ON c.customer_id = f.customer_id
WHERE JULIANDAY(f.first_order_date) >= JULIANDAY(c.joined_date)
ORDER BY days_to_first_order DESC
LIMIT 20;

--13. Year-over-Year Revenue Comparison (YoY)
--For each month, compare revenue with the same month in the previous year using LAG() OVER PARTITION BY month.

WITH monthly AS (
  SELECT year, month,
    ROUND(SUM(gross_revenue),2) AS monthly_rev
  FROM sushi_daily_pnl
  GROUP BY year, month
)
SELECT year, month, monthly_rev,
  LAG(monthly_rev) OVER (PARTITION BY month ORDER BY year) AS prev_year_same_month,
  ROUND((monthly_rev - LAG(monthly_rev) OVER (PARTITION BY month ORDER BY year))
    / LAG(monthly_rev) OVER (PARTITION BY month ORDER BY year) * 100, 2) AS yoy_growth_pct
FROM monthly
ORDER BY year, month;

--14. Analysis by Number of Menu Items per Order
--Calculate the average number of items per order. Compare revenue, tips, and ratings for orders with 1 item, 2–3 items, and 4+ items.

WITH order_item_counts AS (
  SELECT order_id, COUNT(*) AS item_count
  FROM sushi_order_items
  GROUP BY order_id
)
SELECT 
  CASE 
    WHEN oc.item_count = 1 THEN '1 item'
    WHEN oc.item_count BETWEEN 2 AND 3 THEN '2-3 item'
    ELSE '4+ item'
  END AS order_size,
  COUNT(*) AS order_count,
  ROUND(AVG(o.revenue),2) AS avg_revenue,
  ROUND(AVG(o.tip),2) AS avg_tip,
  ROUND(AVG(o.rating),2) AS avg_rating,
  ROUND(AVG(o.discount),2) AS avg_discount
FROM sushi_orders o
JOIN order_item_counts oc ON o.order_id = oc.order_id
GROUP BY order_size
ORDER BY order_count DESC;

--15. Churn Analysis — Customers Inactive for More Than 90 Days
--Consider customers who have not placed an order for 90+ days as churned. Analyze by segment and average LTV.

WITH last_orders AS (
  SELECT customer_id,
    MAX(date_) AS last_order_date,
    COUNT(*) AS total_orders,
    ROUND(SUM(revenue),2) AS total_spent,
    ROUND(AVG(revenue),2) AS avg_order_value
  FROM sushi_orders
  GROUP BY customer_id
)
SELECT c.segment,
  SUM(CASE WHEN JULIANDAY('2024-12-31') - JULIANDAY(l.last_order_date) > 90 THEN 1 ELSE 0 END) AS churned,
  SUM(CASE WHEN JULIANDAY('2024-12-31') - JULIANDAY(l.last_order_date) <= 90 THEN 1 ELSE 0 END) AS active,
  ROUND(AVG(CASE WHEN JULIANDAY('2024-12-31') - JULIANDAY(l.last_order_date) > 90 THEN l.total_spent END),2) AS churned_avg_ltv,
  ROUND(AVG(CASE WHEN JULIANDAY('2024-12-31') - JULIANDAY(l.last_order_date) <= 90 THEN l.total_spent END),2) AS active_avg_ltv
FROM last_orders l
JOIN sushi_customers c ON l.customer_id = c.customer_id
GROUP BY c.segment
ORDER BY churned DESC;
