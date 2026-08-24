let
Source = "SELECT DISTINCT #(cr)#(lf)    e.employee_id,#(cr)#(lf)    e.full_name,#(cr)#(lf)    e.department,#(cr)#(lf)    e.region#(cr)#(lf)FROM dim_employee e#(cr)#(lf)WHERE e.employee_id IN (#(cr)#(lf)    SELECT employee_id #(cr)#(lf)    FROM fact_sales #(cr)#(lf)    ORDER BY order_date DESC, order_id, order_line_id #(cr)#(lf)    LIMIT 100#(cr)#(lf));"
in
Source