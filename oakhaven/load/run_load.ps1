# Oakhaven load driver — contract v1.1.
# Enables local_infile for the load window only, restores OFF afterward
# (server default on this machine is OFF; see IMPLEMENTATION_PLAN.md).
$mysql = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
$cnf   = "C:\Users\ianfi\.my.cnf"
$sql   = Join-Path $PSScriptRoot "load_all.sql"

& $mysql --defaults-extra-file=$cnf -e "SET GLOBAL local_infile = 1;"
if ($LASTEXITCODE -ne 0) { throw "failed to enable local_infile" }

try {
    Get-Content $sql -Raw | & $mysql --defaults-extra-file=$cnf --local-infile=1 --show-warnings
    if ($LASTEXITCODE -ne 0) { throw "load failed — see output above" }
}
finally {
    & $mysql --defaults-extra-file=$cnf -e "SET GLOBAL local_infile = 0;"
}
Write-Host "load complete; local_infile restored to OFF"
