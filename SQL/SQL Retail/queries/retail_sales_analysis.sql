-- Em ơi, tổng hợp nhanh giúp anh: năm 2021 mình bán được bao nhiêu đơn hàng trên toàn chain? Anh cần con số này cho slide đầu tiên của bài thuyết trình sáng mai. 1 số thôi, không cần chi tiết.

SELECT 
    COUNT( DISTINCT [order_number]) AS sum_order
FROM [retails].[sales]
WHERE YEAR([order_date]) = '2021'

GO
-- Em liệt kê giúp chị toàn bộ category sản phẩm mình đang bán, kèm số SKU trong mỗi category. Chị cần để làm product mix overview cho slide marketing. Sắp theo alphabet.

SELECT 
    [category]
    , COUNT([product_key]) AS sum_category_number
FROM [retails].[products]
GROUP BY [category]
ORDER BY [category]

GO
-- Anh cần top 10 thành phố có nhiều khách hàng nhất để team CRM chọn địa điểm tổ chức event tri ân. Gửi anh: tên city, state, country, và số lượng customer

SELECT 
    TOP 10
    cs.[city]
    , cs.[state]
    , cs.[country]
    , COUNT( DISTINCT CS.[customer_key]) AS total_customer
FROM [retails].[customers] cs
GROUP BY 
    cs.[city]
    , cs.[state]
    , cs.[country]
ORDER BY total_customer DESC

GO
-- Em ơi, chị đang làm P&L tháng 12/2020 cho board meeting. Cần tổng doanh thu tháng 12/2020 trên toàn bộ stores — là số tiền khách  đã trả (giá bán × số lượng), không phải lợi nhuận. Gửi chị 1 con số USD trước 5pm hôm nay.
-- Đi tính tổng doanh thu trên từng đơn hàng 
WITH data_raw AS ( -- Tính số tiền chi tiết cho từng phân loại trên mỗi đơn hàng
    SELECT 
        s.order_number
        , sum(p.unit_price_usd * s.quantity) AS total_invoice_amount
    FROM retails.sales s
    INNER JOIN retails.products p
        ON s.product_key = p.product_key
    WHERE 1 =1 
        AND s.order_date BETWEEN '2020-12-01' AND '2020-12-31'
    GROUP BY
        s.order_number
)
SELECT 
    sum(total_invoice_amount) AS total_revenue_month12
FROM data_raw

GO
-- Mình đang có bao nhiêu store ở từng quốc gia vậy em? Cho anh 1 bảng đơn giản: country + số store. Sắp theo số store giảm dần để thấy nước nào đang dominate.
SELECT 
    s.country
    , COUNT(*) AS total_store    
FROM retails.stores s
WHERE s.state != 'Online'
GROUP BY s.country
ORDER BY total_store DESC

GO
-- Em ơi, team merchandising đang lập kế hoạch restock Q1. Anh cần biết top 5 sản phẩm bán chạy nhất trong mỗi category để quyết định nhập hàng. 'Bán chạy' = tổng số lượng bán ra từ trước đến nay. Output 1 bảng: mỗi dòng 1 sản phẩm, có category, tên sản phẩm, tổng lượng bán, và thứ hạng (1-5) trong category đó.

WITH data_raw AS (
    SELECT
        s.product_key
        , SUM(s.quantity) AS sum_quantity_product
    FROM retails.sales s
    GROUP BY s.product_key
),
ranked_products AS (
    SELECT
        p.category
        , p.product_name
        , d.sum_quantity_product
        , DENSE_RANK() OVER (PARTITION BY p.category ORDER BY d.sum_quantity_product DESC) AS rank_quantity
    FROM retails.products p
    INNER JOIN data_raw d
        ON d.product_key = p.product_key
)
SELECT
    category
    , product_name
    , sum_quantity_product
    , rank_quantity
FROM ranked_products
WHERE rank_quantity <= 5
ORDER BY category, rank_quantity

GO
-- Chị cần biết margin gross trung bình của từng subcategory để đánh giá pricing strategy. Margin % = (giá bán − giá vốn) / giá bán. Chỉ xét subcategory có ít nhất 10 sản phẩm để số có ý nghĩa. Sắp theo margin giảm dần.
SELECT 
    p.subcategory
    , ROUND( AVG((p.unit_price_usd - p.unit_cost_usd) * 100/p.unit_price_usd), 2) AS margin_product
FROM retails.products p
GROUP BY p.subcategory
HAVING COUNT(p.product_key) >= 10
ORDER BY margin_product DESC

GO
-- Em giúp anh check SLA giao hàng nhé. Lưu ý: chỉ những đơn có phát sinh giao hàng tới tay khách mới có ngày giao — đơn mua trực tiếp tại cửa hàng thì không. Với nhóm đơn có giao đó, trung bình từ lúc khách đặt đến lúc nhận hàng là bao nhiêu ngày, tính theo từng quốc gia của khách? Gửi anh: tên nước, số đơn có giao, số ngày trung bình — sắp theo số ngày trung bình giảm dần để anh thấy nước nào đang giao chậm nhất.
SELECT 
    c.country
    , COUNT(DISTINCT s.order_number) AS count_order
    , AVG(DATEDIFF( DAY, s.order_date, s.delivery_date)) AS avg_delivery_date
FROM retails.sales s
INNER JOIN retails.customers c
    ON s.customer_key = c.customer_key
WHERE delivery_date IS NOT NULL
GROUP BY c.country
ORDER BY avg_delivery_date DESC

GO
-- Chị cần chuẩn bị danh sách khách VIP theo từng quốc gia để team CRM làm campaign tri ân cuối năm. Ở mỗi nước, cho chị 1 khách hàng chi tiêu nhiều nhất trong năm 2020. Output: country, tên khách, tổng chi tiêu 2020.
WITH data_raw_total_spending AS( -- tính tổng doanh thu theo từng khách hàng
    SELECT 
        s.customer_key
        , SUM(s.quantity * p.unit_price_usd) AS total_spending
    FROM retails.sales s
    INNER JOIN retails.products p
        ON p.product_key = s.product_key
    WHERE YEAR(s.order_date) = 2020
    GROUP BY s.customer_key
), 
data_raw_rank_country AS ( 
    SELECT
        c.country
        , c.name
        , d.total_spending
        , DENSE_RANK() OVER ( PARTITION BY c.country ORDER BY d.total_spending DESC) AS rank_spending_country 
    FROM data_raw_total_spending d
    INNER JOIN retails.customers c
        ON c.customer_key = d.customer_key
)
SELECT
    country
    , name
    , total_spending
FROM data_raw_rank_country
WHERE rank_spending_country = 1

GO
-- Merchandising nghi có sản phẩm nằm trong catalog nhưng chưa từng bán được cái nào — zombie inventory. Em list giúp anh toàn bộ SKU đó để team clearance xử lý. Gửi anh: mã sản phẩm, tên sản phẩm, brand, category.
SELECT 
    p.product_key
    , p.product_name
    , p.brand
    , p.category
FROM retails.products p
LEFT JOIN retails.sales s 
    ON s.product_key = p.product_key
WHERE s.product_key IS NULL

GO
-- Chị cần slide cho CEO presentation show doanh thu từng tháng + doanh thu tích luỹ từ đầu period 24 tháng gần nhất. Tháng-doanh thu để nhìn trend, tích luỹ để nhìn scale. Xuất 1 bảng: year_month, doanh thu tháng đó, doanh thu cộng dồn.
WITH data_raw_1 AS ( 
    SELECT
        FORMAT( s.order_date, 'yyyy - MM') AS YearMonth 
        , DATEFROMPARTS( YEAR(s.order_date), MONTH(s.order_date), 1) AS MonthStart
        , SUM( s.quantity * p.unit_price_usd) AS total_revenue_bill
    FROM retails.sales s
    INNER JOIN retails.products p
        ON p.product_key = s.product_key
    WHERE s.order_date >= DATEADD( MONTH, -24, (SELECT MAX(order_date) FROM retails.sales))
    GROUP BY FORMAT( s.order_date, 'yyyy - MM'), DATEFROMPARTS( YEAR(s.order_date), MONTH(s.order_date), 1) 
)
SELECT 
    YearMonth
    , total_revenue_bill
    , SUM(total_revenue_bill) OVER( ORDER BY MonthStart) AS cumulative_revenue
FROM data_raw_1 d1
ORDER BY MonthStart

GO
-- Anh đang nghi có vấn đề về retention nhưng chưa có proof. Em giúp anh: khách lần đầu mua năm X có bao nhiêu % quay lại mua ở năm X+1, X+2, X+3? Gom khách theo năm họ mua đầu tiên. Xuất matrix: năm mua đầu × số năm sau (0, 1, 2, 3) × % retention. Anh cần báo cáo cho board meeting quarter sau.
WITH _year_purchase AS ( 
    SELECT 
        DISTINCT s.customer_key
        , YEAR(MIN(s.order_date)) AS year_start_buy
    FROM retails.sales s
    GROUP BY s.customer_key
), other_year AS ( 
    SELECT
        DISTINCT yp.customer_key
        , yp.year_start_buy 
        , YEAR(s.order_date) AS other_year
        , YEAR(s.order_date) - yp.year_start_buy AS number_client_year
    FROM _year_purchase yp
    INNER JOIN retails.sales s
        ON s.customer_key = yp.customer_key
), cohort_analysis AS ( 
    SELECT 
        ot.year_start_buy
        , ot.number_client_year
        , COUNT( DISTINCT ot.customer_key) AS count_customer
    FROM other_year ot
    GROUP BY ot.year_start_buy, ot.number_client_year
), cohort_size AS ( 
    SELECT 
        ca.year_start_buy
        , ca.count_customer AS total_customer
    FROM cohort_analysis ca
    WHERE ca.number_client_year = 0
)

SELECT 
    cs.year_start_buy
    , ROUND( 100.0 * MAX( CASE WHEN ca.number_client_year = 1 THEN ca.count_customer END) / cs.total_customer, 2) AS  retention_1yr
    , ROUND( 100.0 * MAX( CASE WHEN ca.number_client_year = 2 THEN ca.count_customer END) / cs.total_customer, 2) AS  retention_2yr
    , ROUND( 100.0 * MAX( CASE WHEN ca.number_client_year = 3 THEN ca.count_customer END) / cs.total_customer, 2) AS  retention_3yr
FROM cohort_size cs
INNER JOIN cohort_analysis ca
    ON cs.year_start_buy = ca.year_start_buy
GROUP BY cs.year_start_buy, cs.total_customer
ORDER BY cs.year_start_buy

GO
-- Em tính giúp chị doanh thu trên mỗi mét vuông của từng store để so sánh hiệu quả sử dụng diện tích. Sau đó xếp hạng 4 nhóm (quartile) trong cùng quốc gia — store nào top 25%, store nào bottom 25%. Xuất: store_key, country, doanh thu/m², quartile trong nước.
WITH total_revenue AS ( 
    SELECT 
        s.store_key
        , sum(s.quantity * p.unit_price_usd) AS order_value
    FROM retails.sales s
    INNER JOIN retails.products p
        ON s.product_key = p.product_key
    WHERE s.order_date >= DATEADD(MONTH, -12, (SELECT MAX(order_date) FROM retails.sales))
    GROUP BY s.store_key
), revenue_acreage AS (
    SELECT
        st.store_key
        , st.country
        , tr.order_value / st.square_meters AS square_revenue
    FROM retails.stores st
    INNER JOIN total_revenue tr
        ON tr.store_key = st.store_key
    WHERE st.country != 'Online'
), quartile_rank AS (
    SELECT
        ra.store_key
        , ra.country
        , ra.square_revenue
        , NTILE(4) OVER( PARTITION BY ra.country ORDER BY ra.square_revenue DESC) AS quartile
    FROM revenue_acreage ra
)
SELECT
    qr.store_key
    , qr.country
    , qr.square_revenue
    , CASE qr.quartile
        WHEN 1 THEN 'Top 25%'
        WHEN 2 THEN 'Upper-middle'
        WHEN 3 THEN 'Lower-middle'
        ELSE 'Bottom 25%'
    END AS quartile_label
FROM quartile_rank qr
ORDER BY qr.store_key

GO
-- Team marketing đang thiết kế recommendation engine, cần insight: những cặp sản phẩm nào hay được mua chung trong cùng 1 đơn hàng? Em lấy giúp top 20 cặp xuất hiện cùng nhau nhiều nhất, chỉ xét đơn có từ 2 sản phẩm khác nhau trở lên. Output: sản phẩm A, sản phẩm B, số lần xuất hiện cùng, tỷ lệ trên tổng số đơn.
WITH valid_orders AS ( 
    SELECT 
        DISTINCT s.order_number
        , COUNT( DISTINCT s.product_key) AS count_item
    FROM retails.sales s
    GROUP BY s.order_number
    HAVING COUNT( DISTINCT s.product_key) > 1
), product_pairs AS (
    SELECT 
        vo.order_number
        , s1.product_key AS product_1
        , s2.product_key AS product_2
    FROM retails.sales s1
    JOIN retails.sales s2
        ON s1.order_number = s2.order_number
    INNER JOIN valid_orders vo
        ON vo.order_number = s1.order_number
    WHERE s1.product_key < s2.product_key
), count_pair_product AS ( 
    SELECT
        pp.product_1
        , pp.product_2 
        , COUNT( DISTINCT pp.order_number) AS pair_count
        , ( 
            SELECT 
                COUNT( DISTINCT vo.order_number)
            FROM valid_orders vo
        ) AS count_all
    FROM product_pairs pp 
    GROUP BY pp.product_1, pp.product_2
)
SELECT 
    TOP 20
    cpp.product_1
    , cpp.product_2
    , cpp.pair_count
    , cpp.pair_count * 100.0 / cpp.count_all AS a
FROM count_pair_product cpp
ORDER BY pair_count DESC

GO




