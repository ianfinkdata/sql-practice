let
    // 1. Execute the Python script and inject your parameters safely with explicit Int64 types
    Source = Python.Execute("import sqlite3#(lf)import pandas as pd#(lf)import matplotlib as mpl#(lf)#(lf)conn = sqlite3.connect(""C:\Github\sql-practice\project\oakhaven.db"")#(lf)df = pd.read_sql_query(""""""#(lf)SELECT DISTINCT #(lf)    d.datekey,#(lf)    d.date,#(lf)    d.year,#(lf)    d.month,#(lf)    d.month_name,#(lf)    d.quarter,#(lf)    d.day_name,#(lf)    d.is_weekend#(lf)FROM dim_date d#(lf)WHERE d.datekey IN (#(lf)    SELECT datekey #(lf)    FROM fact_sales #(lf)    ORDER BY order_date DESC, order_id, order_line_id #(lf)    LIMIT 100#(lf));#(lf)"""""", conn, dtype={'datekey': 'Int64', 'year': 'Int64', 'month': 'Int64', 'is_weekend': 'Int64'})#(lf)conn.close()"),

    // 2. Extract the dataframe 'df' that Python generated
    DataTable = Source{[Name="df"]}[Value],

    // 3. Transform column data types
    #"Changed Type" = Table.TransformColumnTypes(DataTable,{
        {"datekey", Int64.Type},
        {"date", type date},
        {"year", Int64.Type},
        {"month", Int64.Type},
        {"month_name", type text},
        {"quarter", type text},
        {"day_name", type text},
        {"is_weekend", Int64.Type}
    })
in
    #"Changed Type"
