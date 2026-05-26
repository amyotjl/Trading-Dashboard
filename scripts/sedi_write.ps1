# sedi_write.ps1
# Reads the SEDI CSV from the clipboard (written there by sedi_extract.js via the browser)
# and saves it to A:\HelloWorld\data\ with a date-stamped filename.
#
# Usage (called by the scheduled task after the browser copies the CSV):
#   pwsh -File "A:\HelloWorld\scripts\sedi_write.ps1" -Date "2026-05-24"

param(
    [Parameter(Mandatory=$true)]
    [string]$Date   # YYYY-MM-DD format — the transaction date that was fetched
)

$outputDir  = "A:\HelloWorld\data"
$outputFile = Join-Path $outputDir "sedi_insider_transactions_$Date.csv"

$csv = Get-Clipboard -Raw

if (-not $csv -or $csv.Trim().Length -eq 0) {
    Write-Error "Clipboard is empty — did sedi_extract.js run successfully?"
    exit 1
}

$lineCount = ($csv -split "`n").Count
if ($lineCount -lt 2) {
    Write-Error "Clipboard content looks wrong (only $lineCount line(s)). Aborting."
    exit 1
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$csv | Out-File -FilePath $outputFile -Encoding UTF8 -NoNewline

$dataRows = $lineCount - 1
Write-Host "Saved $dataRows transactions to: $outputFile"

# Sanitize the raw file into the format expected by TransactionImportService
$sanitizeScript = Join-Path $PSScriptRoot "sedi_sanitize.ps1"
Write-Host "Running sanitize step..."
& pwsh -File $sanitizeScript -Date $Date
if ($LASTEXITCODE -ne 0) {
    Write-Error "Sanitize step failed (exit code $LASTEXITCODE)."
    exit $LASTEXITCODE
}
