Param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$reportsDir = Join-Path $repoRoot 'reports'

if (-not (Test-Path $reportsDir)) {
    Write-Error "Reports directory not found: $reportsDir"
    exit 2
}

# Collect HTML report files but exclude previously generated combined reports
$files = Get-ChildItem -Path $reportsDir -Filter '*.html' | Where-Object { $_.Name -notlike 'general_report*' } | Sort-Object Name
if ($files.Count -eq 0) {
    Write-Host "No HTML report files found in $reportsDir"
    exit 0
}

# Read head from first original report
$firstContent = Get-Content -Raw -Path $files[0].FullName
$headMatch = [regex]::Match($firstContent, '(?s)<head.*?</head>')
if ($headMatch.Success) {
    $headHtml = $headMatch.Value
} else {
    $headHtml = '<head><meta charset="utf-8" /><title>Combined Report</title></head>'
}

# Inject a small visual wrapper style to make the combined report readable
$injectedStyle = @"
<style>
    body { font-family: Inter, -apple-system, 'Segoe UI', Roboto, sans-serif; background: #f3f4f6; color: #1f2937; }
    main { max-width: 1200px; margin: 2rem auto; background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.08); }
    .combined-report-item { margin-bottom: 2rem; }
    .combined-report-item h2 { margin: 0 0 0.75rem 0; padding: 0.25rem 0.5rem; background: #eef2ff; display: inline-block; border-radius: 6px; font-size: 1rem; }
    hr { border: none; border-top: 1px solid #e5e7eb; margin: 2rem 0; }
</style>
"@

# Attempt to insert injectedStyle into the head HTML
if ($headHtml -match '(?i)</head>') {
    $headHtml = $headHtml -replace '(?i)</head>', "$injectedStyle`n</head>"
} else {
    $headHtml = "$headHtml`n$injectedStyle"
}

$bodies = @()
$i = 0
foreach ($f in $files) {
    $i++
    $c = Get-Content -Raw -Path $f.FullName
    $m = [regex]::Match($c, '(?s)<body.*?>(.*?)</body>')
    if ($m.Success) {
        $inner = $m.Groups[1].Value.Trim()
    } else {
        $inner = $c
    }

    # Unique prefix per report
    $prefix = "r${i}_"

    # Prefix id attributes
    $inner = [regex]::Replace($inner, 'id="([^"]+)"', { param($mm) 'id="' + $prefix + $mm.Groups[1].Value + '"' })

    # Prefix for attributes (labels)
    $inner = [regex]::Replace($inner, 'for="([^"]+)"', { param($mm) 'for="' + $prefix + $mm.Groups[1].Value + '"' })

    # Prefix name attributes (important for radio groups)
    $inner = [regex]::Replace($inner, 'name="([^"]+)"', { param($mm) 'name="' + $prefix + $mm.Groups[1].Value + '"' })

    # Prefix aria-controls
    $inner = [regex]::Replace($inner, 'aria-controls="([^"]+)"', { param($mm) 'aria-controls="' + $prefix + $mm.Groups[1].Value + '"' })

    # Prefix href anchors that are fragment identifiers
    $inner = [regex]::Replace($inner, 'href="#([^"]+)"', { param($mm) 'href="#' + $prefix + $mm.Groups[1].Value + '"' })

    $section = "<section class='combined-report-item' id='${prefix}section'>`n<h2>$($f.BaseName)</h2>`n" + $inner + "`n</section>"
    $bodies += $section
}

$combinedBody = $bodies -join "`n<hr/>`n"

$final = "<!DOCTYPE html>`n<html>`n$headHtml`n<body>`n<main>`n$combinedBody`n</main>`n</body>`n</html>"

# Only write timestamped output as requested by the user
$timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
$timeFile = Join-Path $reportsDir ("general_report_$timestamp.html")
Set-Content -Path $timeFile -Value $final -Encoding UTF8

Write-Host "Wrote: $timeFile"
exit 0
