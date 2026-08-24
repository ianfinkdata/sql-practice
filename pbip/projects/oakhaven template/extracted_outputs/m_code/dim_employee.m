let
    // 1. Execute the Python script and inject your parameters safely with explicit Int64 types
    Source = Python.Execute("import sqlite3#(lf)import pandas as pd#(lf)import matplotlib as mpl#(lf)#(lf)conn = sqlite3.connect(""C:\Github\sql-practice\project\oakhaven.db"")#(lf)df = pd.read_sql_query(""""""#(lf)SELECT DISTINCT #(lf)    e.employee_id,#(lf)    e.full_name,#(lf)    e.department,#(lf)    e.region#(lf)FROM dim_employee e#(lf)WHERE e.employee_id IN (#(lf)    SELECT employee_id #(lf)    FROM fact_sales #(lf)    ORDER BY order_date DESC, order_id, order_line_id #(lf)    LIMIT 100#(lf));#(lf)"""""", conn, dtype={'employee_id': 'Int64'})#(lf)conn.close()"),

    // 2. Extract the dataframe 'df' that Python generated
    DataTable = Source{[Name="df"]}[Value],

    // 3. Transform column data types
    #"Changed Type" = Table.TransformColumnTypes(DataTable,{
        {"employee_id", Int64.Type},
        {"full_name", type text},
        {"department", type text},
        {"region", type text}
    })
in
    #"Changed Type"