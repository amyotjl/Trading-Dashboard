# sedi_sanitize.ps1
# Transforms a raw SEDI CSV (20-column File 2 format) into the 13-column
# snake_case format expected by TransactionImportService, and resolves tickers.
#
# Ticker resolution order:
#   1. issuers table in the running PostgreSQL container
#   2. Enrichment service /search endpoint (Yahoo Finance)
#   3. "No Symbol Found" fallback
#
# Usage (called by the routine after sedi_write.ps1):
#   pwsh -File "A:\HelloWorld\scripts\sedi_sanitize.ps1" -Date "2026-05-25"

param(
    [Parameter(Mandatory = $true)]
    [string]$Date
)

$dataDir     = "A:\HelloWorld\data"
$inputFile   = Join-Path $dataDir "sedi_insider_transactions_$Date.csv"
$outputFile  = Join-Path $dataDir "sedi_sanitized_$Date.csv"
$composePath = "A:\HelloWorld\docker-compose.yml"
$enrichUrl   = "http://localhost:8000"

# ── Validate input ─────────────────────────────────────────────────────────────

if (-not (Test-Path $inputFile)) {
    Write-Error "Input file not found: $inputFile"
    exit 1
}

$rows = Import-Csv -Path $inputFile
if ($rows.Count -eq 0) {
    Write-Error "Input file has no data rows."
    exit 1
}

Write-Host "Loaded $($rows.Count) rows from $inputFile"

# ── Helpers ────────────────────────────────────────────────────────────────────

function Get-DbTickers {
    param([string[]]$Names)

    $map = @{}
    if ($Names.Count -eq 0) { return $map }

    $inList = ($Names | ForEach-Object {
        "'" + $_.ToLower().Replace("'", "''") + "'"
    }) -join ","

    $sql = "SELECT LOWER(name), ticker FROM issuers WHERE ticker IS NOT NULL AND LOWER(name) IN ($inList)"

    try {
        $output = docker compose -f $composePath exec -T db `
            psql -U postgres -d sedi_development -t -A -c $sql 2>&1
        foreach ($line in $output) {
            $parts = $line.Trim() -split '\|'
            if ($parts.Count -ge 2 -and $parts[0].Trim() -and $parts[1].Trim()) {
                $map[$parts[0].Trim()] = $parts[1].Trim()
            }
        }
    } catch {
        Write-Warning "DB lookup failed: $_"
    }
    return $map
}

function Get-EnrichmentTicker {
    param([string]$Name)

    try {
        $encoded = [Uri]::EscapeDataString($Name)
        $resp = Invoke-RestMethod -Uri "$enrichUrl/search?q=$encoded" `
            -Method Get -TimeoutSec 10 -ErrorAction Stop
        return $resp.symbol
    } catch {
        return $null
    }
}

function Clean-Number {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return "" }
    return ($Raw -replace ',', '') -replace '^\+', ''
}

function Format-OwnershipType {
    param([string]$Type, [string]$Holder)
    $t = $Type.Trim()
    $h = $Holder.Trim()
    if ($t -eq "Direct Ownership") {
        return "Direct Ownership :"
    } elseif ($t -eq "Indirect Ownership" -or $t -eq "Control or Direction") {
        return "$t$h"
    } else {
        # Issuer or other — pass through with trailing marker
        return "$t :"
    }
}

# ── Batch ticker resolution ────────────────────────────────────────────────────

$uniqueNames = @($rows | ForEach-Object { $_.'Issuer Name'.Trim() } | Sort-Object -Unique)
Write-Host "Resolving tickers for $($uniqueNames.Count) unique issuers..."

$tickerMap = Get-DbTickers -Names $uniqueNames
Write-Host "  DB: $($tickerMap.Count) found"

$unknown   = $uniqueNames | Where-Object { -not $tickerMap.ContainsKey($_.ToLower()) }
$yahooHits = 0
foreach ($name in $unknown) {
    $symbol = Get-EnrichmentTicker -Name $name
    if ($symbol) {
        $tickerMap[$name.ToLower()] = $symbol
        $yahooHits++
        Write-Host "  Yahoo: $name -> $symbol"
    } else {
        $tickerMap[$name.ToLower()] = "No Symbol Found"
        Write-Host "  Yahoo: $name -> not found"
    }
}
Write-Host "  Yahoo: $yahooHits found, $($unknown.Count - $yahooHits) unresolved"

# ── Transform rows ─────────────────────────────────────────────────────────────

$outputRows = foreach ($row in $rows) {
    $issuerName = $row.'Issuer Name'.Trim()
    $ticker     = $tickerMap[$issuerName.ToLower()]
    if (-not $ticker) { $ticker = "No Symbol Found" }

    $balance = (Clean-Number $row.'Closing Balance')
    if ([string]::IsNullOrWhiteSpace($balance)) {
        $balance = Clean-Number $row.'Insider Calculated Balance'
    }

    [PSCustomObject]@{
        insider_name           = $row.'Insider Name'.Trim()
        relationship           = $row.'Insider Relationship to Issuer'.Trim()
        security_designation   = $row.'Security Designation'.Trim()
        issuer_name            = $issuerName
        ticker                 = $ticker
        transaction_id         = $row.'Transaction ID'.Trim()
        transaction_date       = $row.'Date of Transaction'.Trim()
        filing_date            = $row.'Date of Filing'.Trim()
        ownership_type         = Format-OwnershipType $row.'Ownership Type' $row.'Registered Holder'
        nature_of_transaction  = $row.'Nature of Transaction'.Trim()
        number_of_securities   = Clean-Number $row.'Number or Value Acquired or Disposed'
        unit_price             = Clean-Number $row.'Unit Price or Exercise Price'
        balance                = $balance
    }
}

# ── Write output (UTF-8 without BOM) ──────────────────────────────────────────

$csvLines = $outputRows | ConvertTo-Csv -NoTypeInformation
[System.IO.File]::WriteAllLines($outputFile, $csvLines, [System.Text.UTF8Encoding]::new($false))

Write-Host "Saved $($outputRows.Count) rows to: $outputFile"
