let
Source = "SELECT #(cr)#(lf)    f.order_id,#(cr)#(lf)    f.order_line_id,#(cr)#(lf)    f.order_date,#(cr)#(lf)    c.full_name AS customer_name,#(cr)#(lf)    p.product_name,#(cr)#(lf)    p.category AS product_category,#(cr)#(lf)    f.quantity,#(cr)#(lf)    f.net_amount,#(cr)#(lf)    f.channel#(cr)#(lf)FROM fact_sales f#(cr)#(lf)LEFT JOIN dim_customer c ON f.customer_id = c.customer_id#(cr)#(lf)LEFT JOIN dim_product p ON f.product_id = p.product_id#(cr)#(lf)WHERE f.order_status = 'Completed'#(cr)#(lf)ORDER BY f.order_date DESC#(cr)#(lf)LIMIT 100;"
in
Source
