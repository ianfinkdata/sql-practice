let
    // 1. Execute the Python script and inject your parameters safely with explicit Int64 types
    Source = Python.Execute("import sqlite3#(lf)import pandas as pd#(lf)import matplotlib as mpl#(lf)#(lf)conn = sqlite3.connect(""C:\Github\sql-practice\project\oakhaven.db"")#(lf)df = pd.read_sql_query(""""""#(lf)SELECT DISTINCT #(lf)    c.customer_id,#(lf)    c.full_name,#(lf)    c.email,#(lf)    c.state,#(lf)    c.customer_segment#(lf)FROM dim_customer c#(lf)WHERE c.customer_id IN (#(lf)    SELECT customer_id #(lf)    FROM fact_sales #(lf)    ORDER BY order_date DESC, order_id, order_line_id #(lf)    LIMIT 100#(lf));#(lf)"""""", conn, dtype={'customer_id': 'Int64'})#(lf)conn.close()"),

    // 2. Extract the dataframe 'df' that Python generated
    DataTable = Source{[Name="df"]}[Value],

    // 3. Transform column data types
    #"Changed Type" = Table.TransformColumnTypes(DataTable,{
        {"customer_id", Int64.Type},
        {"full_name", type text},
        {"email", type text},
        {"state", type text},
        {"customer_segment", type text}
    })
in
    #"Changed Type"