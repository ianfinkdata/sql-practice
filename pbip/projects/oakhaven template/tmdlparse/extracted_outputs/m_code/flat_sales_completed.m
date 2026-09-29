let
    // 1. Execute the Python script and inject your parameters safely with explicit Int64 types
    Source = Python.Execute("import sqlite3#(lf)import pandas as pd#(lf)import matplotlib as mpl#(lf)#(lf)conn = sqlite3.connect(""C:\Github\sql-practice\project\oakhaven.db"")#(lf)df = pd.read_sql_query(""""""#(lf)SELECT #(lf)    f.order_id,#(lf)    f.order_line_id,#(lf)    f.order_date,#(lf)    c.full_name AS customer_name,#(lf)    p.product_name,#(lf)    p.category AS product_category,#(lf)    f.quantity,#(lf)    f.net_amount,#(lf)    f.channel#(lf)FROM fact_sales f#(lf)LEFT JOIN dim_customer c ON f.customer_id = c.customer_id#(lf)LEFT JOIN dim_product p ON f.product_id = p.product_id#(lf)WHERE f.order_status = 'Completed'#(lf)ORDER BY f.order_date DESC#(lf)LIMIT 100;#(lf)"""""", conn, dtype={'order_id': 'Int64', 'order_line_id': 'Int64', 'quantity': 'Int64'})#(lf)conn.close()"),

    // 2. Extract the dataframe 'df' that Python generated
    DataTable = Source{[Name="df"]}[Value],

    // 3. Transform column data types
    #"Changed Type" = Table.TransformColumnTypes(DataTable,{
        {"order_id", Int64.Type},
        {"order_line_id", Int64.Type},
        {"order_date", type date},
        {"customer_name", type text},
        {"product_name", type text},
        {"product_category", type text},
        {"quantity", Int64.Type},
        {"net_amount", type number},
        {"channel", type text}
    })
in
    #"Changed Type"
