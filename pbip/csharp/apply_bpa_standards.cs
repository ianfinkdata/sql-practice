// apply_bpa_standards.cs
// Tabular Editor C# Script: Automated BPA Standards & Batch Model Refactoring
// Usage (TE2/TE3 CLI):
//   tabulareditor3 "path/to/SemanticModel" --script "apply_bpa_standards.cs" --save
//   TabularEditor.exe "path/to/SemanticModel" -S "apply_bpa_standards.cs" -B

#r "Microsoft.AnalysisServices.Tabular"
using System;
using System.Linq;
using System.Text.RegularExpressions;
using Microsoft.AnalysisServices.Tabular;

Output("==================================================================");
Output("  TABULAR EDITOR CLI: APPLYING BPA STANDARDS & BATCH MEASURES    ");
Output("==================================================================");

// 1. Ensure Centralized '_Measures' Table Exists
Table measureTable = Model.Tables.FirstOrDefault(t => t.Name.Equals("_Measures", StringComparison.OrdinalIgnoreCase) || t.Name.Equals("_measures", StringComparison.OrdinalIgnoreCase));

if (measureTable == null)
{
    Output("Creating centralized '_Measures' table...");
    measureTable = Model.AddCalculatedTable("_Measures", "ROW(\"Value\", 1)");
    measureTable.Description = "Centralized repository for all business reporting DAX measures.";
    
    // Hide default column
    if (measureTable.Columns.Contains("Value"))
    {
        measureTable.Columns["Value"].IsHidden = true;
    }
}

// 2. Centralize All Measures into '_Measures' Table
int movedMeasures = 0;
foreach (var t in Model.Tables.ToList())
{
    if (t == measureTable) continue;
    foreach (var m in t.Measures.ToList())
    {
        Output($"Moving measure '{m.Name}' from '{t.Name}' to '{measureTable.Name}'...");
        m.Table = measureTable;
        movedMeasures++;
    }
}
Output($"Total measures centralized: {movedMeasures}");

// 3. Batch Apply Descriptions, Format Strings, and Display Folders
int updatedMeasures = 0;
foreach (var m in Model.AllMeasures)
{
    bool updated = false;

    // A. Format String Standardization
    if (string.IsNullOrWhiteSpace(m.FormatString))
    {
        if (m.Name.Contains("%") || m.Name.Contains("Rate") || m.Name.Contains("Pct") || m.Name.Contains("Percent"))
        {
            m.FormatString = "0.0%";
        }
        else if (m.Name.Contains("$") || m.Name.Contains("Revenue") || m.Name.Contains("Amount") || m.Name.Contains("Price") || m.Name.Contains("Cost") || m.Name.Contains("Margin") || m.Name.Contains("AOV") || m.Name.Contains("Value"))
        {
            m.FormatString = @"\$#,##0.00";
        }
        else if (m.Name.Contains("Count") || m.Name.Contains("Orders") || m.Name.Contains("Units") || m.Name.Contains("Quantity"))
        {
            m.FormatString = "#,##0";
        }
        else
        {
            m.FormatString = "#,##0.00";
        }
        updated = true;
    }

    // B. Display Folder Categorization
    if (string.IsNullOrWhiteSpace(m.DisplayFolder))
    {
        if (m.Name.Contains("YoY") || m.Name.Contains("MoM") || m.Name.Contains("PY") || m.Name.Contains("YTD"))
        {
            m.DisplayFolder = "05 - Time Intelligence";
        }
        else if (m.Name.Contains("Margin") || m.Name.Contains("Profit") || m.Name.Contains("COGS") || m.Name.Contains("Cost"))
        {
            m.DisplayFolder = "02 - Margins & Profitability";
        }
        else if (m.Name.Contains("Order") || m.Name.Contains("AOV") || m.Name.Contains("Basket"))
        {
            m.DisplayFolder = "03 - Order Metrics";
        }
        else if (m.Name.Contains("Customer") || m.Name.Contains("User") || m.Name.Contains("Client"))
        {
            m.DisplayFolder = "04 - Customer Metrics";
        }
        else
        {
            m.DisplayFolder = "01 - Revenue & Volume";
        }
        updated = true;
    }

    // C. Provide Default Description if Blank
    if (string.IsNullOrWhiteSpace(m.Description))
    {
        m.Description = $"Calculated metric for {m.Name}.";
        updated = true;
    }

    if (updated) updatedMeasures++;
}
Output($"Total measures formatted & categorized: {updatedMeasures}");

// 4. Batch Hide Foreign Keys in Fact Tables and Surrogate Keys
int hiddenColumns = 0;
foreach (var rel in Model.Relationships.ToList())
{
    if (rel.FromColumn != null && !rel.FromColumn.IsHidden)
    {
        Output($"Hiding foreign key column '{rel.FromTable.Name}[{rel.FromColumn.Name}]'...");
        rel.FromColumn.IsHidden = true;
        hiddenColumns++;
    }
}

foreach (var col in Model.AllColumns)
{
    if (!col.IsHidden && !col.Table.Name.StartsWith("dim_", StringComparison.OrdinalIgnoreCase))
    {
        if (col.Name.EndsWith("key", StringComparison.OrdinalIgnoreCase) || 
            (col.Name.EndsWith("_id", StringComparison.OrdinalIgnoreCase) && col.Table.Name.StartsWith("fact_", StringComparison.OrdinalIgnoreCase)))
        {
            col.IsHidden = true;
            hiddenColumns++;
        }
    }
}
Output($"Total relationship/surrogate key columns hidden: {hiddenColumns}");

Output("------------------------------------------------------------------");
Output("✅ [SUCCESS] Model refactoring & BPA standards successfully applied!");
Output("------------------------------------------------------------------");
