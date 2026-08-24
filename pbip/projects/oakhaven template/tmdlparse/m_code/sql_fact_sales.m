let
Source = "SELECT #(cr)#(lf)    f.order_id,#(cr)#(lf)    f.order_line_id,#(cr)#(lf)    f.customer_id,#(cr)#(lf)    f.product_id,#(cr)#(lf)    f.employee_id,#(cr)#(lf)    f.datekey,#(cr)#(lf)    f.quantity,#(cr)#(lf)    f.unit_price,#(cr)#(lf)    f.discount_pct,#(cr)#(lf)    f.net_amount,#(cr)#(lf)    f.payment_method,#(cr)#(lf)    f.order_status,#(cr)#(lf)    f.channel#(cr)#(lf)FROM fact_sales f#(cr)#(lf)ORDER BY f.order_date DESC, f.order_id, f.order_line_id#(cr)#(lf)LIMIT 100;"
in
Source