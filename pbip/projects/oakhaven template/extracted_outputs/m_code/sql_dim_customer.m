let
Source = "SELECT DISTINCT #(cr)#(lf)    c.customer_id,#(cr)#(lf)    c.full_name,#(cr)#(lf)    c.email,#(cr)#(lf)    c.state,#(cr)#(lf)    c.customer_segment#(cr)#(lf)FROM dim_customer c#(cr)#(lf)WHERE c.customer_id IN (#(cr)#(lf)    SELECT customer_id #(cr)#(lf)    FROM fact_sales #(cr)#(lf)    ORDER BY order_date DESC, order_id, order_line_id #(cr)#(lf)    LIMIT 100#(cr)#(lf));"
in
Source