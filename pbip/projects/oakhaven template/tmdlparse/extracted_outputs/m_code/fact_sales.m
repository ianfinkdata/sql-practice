let
    // 1. Execute the Python script and inject your parameters safely with explicit Int64 types
    Source = Python.Execute("import sqlite3#(lf)import pandas as pd#(lf)import matplotlib as mpl#(lf)#(lf)conn = sqlite3.connect(""C:\Github\sql-practice\project\oakhaven.db"")#(lf)df = pd.read_sql_query(""""""#(lf)SELECT #(lf)    f.order_id,#(lf)    f.order_line_id,#(lf)    f.customer_id,#(lf)    f.product_id,#(lf)    f.employee_id,#(lf)    f.datekey,#(lf)    f.quantity,#(lf)    f.unit_price,#(lf)    f.discount_pct,#(lf)    f.net_amount,#(lf)    f.payment_method,#(lf)    f.order_status,#(lf)    f.channel#(lf)FROM fact_sales f#(lf)ORDER BY f.order_date DESC, f.order_id, f.order_line_id#(lf)LIMIT 100;#(lf)"""""", conn, dtype={'order_id': 'Int64', 'order_line_id': 'Int64', 'customer_id': 'Int64', 'product_id': 'Int64', 'employee_id': 'Int64', 'datekey': 'Int64', 'quantity': 'Int64'})#(lf)conn.close()"),

    // 2. Extract the dataframe 'df' that Python generated
    DataTable = Source{[Name="df"]}[Value],

    // 3. Transform column data types
    #"Changed Type" = Table.TransformColumnTypes(DataTable,{
        {"order_id", Int64.Type},
        {"order_line_id", Int64.Type},
        {"customer_id", Int64.Type},
        {"product_id", Int64.Type},
        {"employee_id", Int64.Type},
        {"datekey", Int64.Type},
        {"quantity", Int64.Type},
        {"unit_price", type number},
        {"discount_pct", type number},
        {"net_amount", type number},
        {"payment_method", type text},
        {"order_status", type text},
        {"channel", type text}
    })
in
    #"Changed Type"
