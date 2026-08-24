let
Source = "SELECT DISTINCT #(cr)#(lf)    d.datekey,#(cr)#(lf)    d.date,#(cr)#(lf)    d.year,#(cr)#(lf)    d.month,#(cr)#(lf)    d.month_name,#(cr)#(lf)    d.quarter,#(cr)#(lf)    d.day_name,#(cr)#(lf)    d.is_weekend#(cr)#(lf)FROM dim_date d#(cr)#(lf)WHERE d.datekey IN (#(cr)#(lf)    SELECT datekey #(cr)#(lf)    FROM fact_sales #(cr)#(lf)    ORDER BY order_date DESC, order_id, order_line_id #(cr)#(lf)    LIMIT 100#(cr)#(lf));"
in
Source