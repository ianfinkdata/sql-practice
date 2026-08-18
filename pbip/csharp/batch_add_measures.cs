// batch_add_measures.cs
// Tabular Editor C# Script: Batch Inject Standard Enterprise DAX Measures
// Usage (TE2/TE3 CLI):
//   tabulareditor3 "path/to/SemanticModel" --script "batch_add_measures.cs" --save
//   TabularEditor.exe "path/to/SemanticModel" -S "batch_add_measures.cs" -B

#r "Microsoft.AnalysisServices.Tabular"
using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.AnalysisServices.Tabular;

Output("==================================================================");
Output("  TABULAR EDITOR CLI: BATCH ENTERPRISE MEASURE GENERATOR          ");
Output("==================================================================");

// 1. Locate or Create '_Measures' Table
Table measureTable = Model.Tables.FirstOrDefault(t => t.Name.Equals("_Measures", StringComparison.OrdinalIgnoreCase) || t.Name.Equals("_measures", StringComparison.OrdinalIgnoreCase));

if (measureTable == null)
{
    Output("Creating centralized '_Measures' table...");
    measureTable = Model.AddCalculatedTable("_Measures", "ROW(\"Value\", 1)");
    measureTable.Description = "Centralized repository for all business reporting DAX measures.";
    if (measureTable.Columns.Contains("Value"))
    {
        measureTable.Columns["Value"].IsHidden = true;
    }
}

// 2. Measure Definitions Catalog
var measureCatalog = new List<(string Name, string DAX, string FormatString, string DisplayFolder, string Description)>
{
    (
        "Total Gross Revenue",
        "SUMX(fact_sales, fact_sales[quantity] * fact_sales[unit_price])",
        @"\$#,##0.00",
        "01 - Revenue & Volume",
        "[Tables: fact_sales] Sum of pre-discount revenue across all sales lines."
    ),
    (
        "Total Net Revenue",
        "SUM(fact_sales[net_amount])",
        @"\$#,##0.00",
        "01 - Revenue & Volume",
        "[Tables: fact_sales] Sum of actual net sales revenue earned after discounts."
    ),
    (
        "Total Units Sold",
        "SUM(fact_sales[quantity])",
        "#,##0",
        "01 - Revenue & Volume",
        "[Tables: fact_sales] Total sum of merchandise item quantities sold."
    ),
    (
        "Total Orders",
        "DISTINCTCOUNT(fact_sales[order_id])",
        "#,##0",
        "03 - Order Metrics",
        "[Tables: fact_sales] Count of distinct sales order transaction IDs."
    ),
    (
        "Average Order Value",
        "DIVIDE([Total Net Revenue], [Total Orders], 0)",
        @"\$#,##0.00",
        "03 - Order Metrics",
        "[Tables: fact_sales] Mean net revenue earned per distinct sales order."
    ),
    (
        "Active Customer Count",
        "DISTINCTCOUNT(fact_sales[customer_id])",
        "#,##0",
        "04 - Customer Metrics",
        "[Tables: fact_sales] Count of unique customers placing orders in selected period."
    ),
    (
        "Overall Discount Rate",
        "DIVIDE([Total Gross Revenue] - [Total Net Revenue], [Total Gross Revenue], 0)",
        "0.0%",
        "01 - Revenue & Volume",
        "[Tables: fact_sales] Weighted average discount percentage across all order lines."
    ),
    (
        "Total Cost of Goods Sold",
        "SUMX(fact_sales, fact_sales[quantity] * RELATED(dim_product[unit_cost]))",
        @"\$#,##0.00",
        "02 - Margins & Profitability",
        "[Tables: dim_product, fact_sales] Total wholesale acquisition cost of all merchandise units sold."
    ),
    (
        "Gross Margin",
        "[Total Net Revenue] - [Total Cost of Goods Sold]",
        @"\$#,##0.00",
        "02 - Margins & Profitability",
        "[Tables: dim_product, fact_sales] Total gross profit (Net Revenue minus Cost of Goods Sold)."
    ),
    (
        "Gross Margin %",
        "DIVIDE([Gross Margin], [Total Net Revenue], 0)",
        "0.0%",
        "02 - Margins & Profitability",
        "[Tables: dim_product, fact_sales] Gross profit percentage of total net revenue."
    ),
    (
        "Net Revenue PY",
        "CALCULATE([Total Net Revenue], SAMEPERIODLASTYEAR(dim_calendar[date]))",
        @"\$#,##0.00",
        "05 - Time Intelligence",
        "[Tables: dim_calendar, fact_sales] Total net revenue for the prior year comparable calendar period."
    ),
    (
        "Net Revenue YoY %",
        "DIVIDE([Total Net Revenue] - [Net Revenue PY], [Net Revenue PY], 0)",
        "0.0%",
        "05 - Time Intelligence",
        "[Tables: dim_calendar, fact_sales] Year-over-year percentage growth in total net revenue."
    )
};

// 3. Batch Add / Update Measures
int added = 0;
int updated = 0;

foreach (var item in measureCatalog)
{
    Measure existing = Model.AllMeasures.FirstOrDefault(m => m.Name.Equals(item.Name, StringComparison.OrdinalIgnoreCase));
    
    if (existing == null)
    {
        Output($"Adding measure: [{item.Name}]");
        var m = measureTable.AddMeasure(item.Name, item.DAX);
        m.FormatString = item.FormatString;
        m.DisplayFolder = item.DisplayFolder;
        m.Description = item.Description;
        added++;
    }
    else
    {
        Output($"Updating existing measure: [{item.Name}]");
        existing.Table = measureTable;
        existing.Expression = item.DAX;
        existing.FormatString = item.FormatString;
        existing.DisplayFolder = item.DisplayFolder;
        existing.Description = item.Description;
        updated++;
    }
}

Output("------------------------------------------------------------------");
Output($"✅ [COMPLETE] Injected {added} new measures, updated {updated} existing measures.");
Output("------------------------------------------------------------------");
