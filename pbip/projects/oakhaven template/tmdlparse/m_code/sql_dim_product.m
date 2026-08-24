let
Source = "SELECT DISTINCT #(cr)#(lf)    p.product_id,#(cr)#(lf)    p.product_name,#(cr)#(lf)    p.category,#(cr)#(lf)    p.subcategory,#(cr)#(lf)    p.brand,#(cr)#(lf)    p.unit_cost,#(cr)#(lf)    p.unit_price#(cr)#(lf)FROM dim_product p#(cr)#(lf)WHERE p.product_id IN (#(cr)#(lf)    SELECT product_id #(cr)#(lf)    FROM fact_sales #(cr)#(lf)    ORDER BY order_date DESC, order_id, order_line_id #(cr)#(lf)    LIMIT 100#(cr)#(lf));"
in
Source