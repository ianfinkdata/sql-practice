# TASK-20260706-01 . run_all_exports.ps1 . 2026-07-07
# PURPOSE: Run all 14 bronze full-row export queries (E01-E14) and write each result set to
#          a tab-separated file under exports\csv\<table>.tsv, for Power BI import.
# GROUNDING: process/mysql-setup.md (IDX-008, Windows connection command + Get-Content -Raw
#            pipe form); grounding/lessons.md RULE-002 (exact connection command; never read
#            or print .my.cnf) and RULE-010 (PowerShell pipe form for multi-line/looped SQL,
#            never -e string quoting or "<" redirection).
# NOTE: mysql's --batch mode renders SQL NULL as the literal 4-character string "NULL", not an
#       empty cell. Power BI's Text/CSV connector will otherwise import it as text. See
#       EXPORT_GUIDE.md for the Power Query fix. Do not treat this rendering as a bug to patch
#       here -- handle it on import instead, per the guide.
# RUN (from this exports/ directory, in PowerShell):
#   .\run_all_exports.ps1

$ErrorActionPreference = "Stop"

# Standard Windows mysql invocation (process/mysql-setup.md, RULE-002). Credentials are never
# hardcoded here -- they come from the same --defaults-extra-file already established for this
# project. This script does not read, print, or otherwise inspect the contents of that file.
$mysqlExe     = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
$defaultsFile = "C:\Users\ianfi\.my.cnf"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvDir    = Join-Path $scriptDir "csv"
New-Item -ItemType Directory -Force -Path $csvDir | Out-Null

# E01-E14 export file -> output table name, same order as grounding/schema.md's table list.
$exports = @(
    @{ File = "E01_stores.sql";              Table = "stores" },
    @{ File = "E02_employees.sql";           Table = "employees" },
    @{ File = "E03_suppliers.sql";           Table = "suppliers" },
    @{ File = "E04_product_categories.sql";  Table = "product_categories" },
    @{ File = "E05_products.sql";            Table = "products" },
    @{ File = "E06_customers.sql";           Table = "customers" },
    @{ File = "E07_promotions.sql";          Table = "promotions" },
    @{ File = "E08_calendar.sql";            Table = "calendar" },
    @{ File = "E09_orders.sql";              Table = "orders" },
    @{ File = "E10_order_items.sql";         Table = "order_items" },
    @{ File = "E11_payments.sql";            Table = "payments" },
    @{ File = "E12_shipments.sql";           Table = "shipments" },
    @{ File = "E13_returns.sql";             Table = "returns" },
    @{ File = "E14_inventory_movements.sql"; Table = "inventory_movements" }
)

foreach ($export in $exports) {
    $sqlPath = Join-Path $scriptDir $export.File
    $outPath = Join-Path $csvDir ($export.Table + ".tsv")
    Write-Host "Exporting $($export.Table) -> $outPath"

    # RULE-010: multi-line/looped SQL goes through a file piped via Get-Content -Raw, never -e
    # string quoting and never "<" redirection (PowerShell has no "<" input redirection).
    Get-Content $sqlPath -Raw |
        & $mysqlExe --defaults-extra-file="$defaultsFile" --batch oakhaven |
        Set-Content -Encoding utf8 $outPath
}

Write-Host "Done. 14 files written to $csvDir"
