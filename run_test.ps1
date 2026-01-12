# run_test.ps1
# Executes k6 tests and automatically attaches HTML reports to created Jira issues
# Usage: . ..\run_test.ps1 -TestIds 001,010 -Profile smoke -CombineReports

param(
    [Parameter(Mandatory=$false)][string[]]$TestIds,
    [Parameter(Mandatory=$false)][switch]$AllTests,
    [Parameter(Mandatory=$false)][string]$Profile = "smoke",
    [Parameter(Mandatory=$false)][switch]$CombineReports
)

# Validate Jira env
if (-not $env:JIRA_BASE_URL -or -not $env:JIRA_EMAIL -or -not $env:JIRA_API_TOKEN) {
    Write-Host "[run_test] Error: Jira variables not set. Run: . ..\set_jira_env.ps1"
    exit 1
}

# Resolve test list
if ($AllTests) {
    $testIdArray = Get-ChildItem "TC*.js" | ForEach-Object { $_.BaseName } | Sort-Object
    $testArgs = "TC"
} elseif ($TestIds) {
    # Format numbers with leading zeros (001, 020, etc.)
    $formattedIds = $TestIds | ForEach-Object { 
        $id = $_.ToString().Trim()
        if ($id -match '^\d+$') {
            '{0:D3}' -f [int]$id
        } else {
            $id
        }
    }
    $testIdArray = $formattedIds
    $testArgs = ($formattedIds -join ',')
} else {
    Write-Host "[run_test] Error: provide -TestIds or -AllTests"
    exit 1
}

Write-Host "[run_test] Running: $($testIdArray -join ', ') with profile: $Profile"

# Keep k6 interactive output visible; capture logs via transcript
$transcriptPath = Join-Path $env:TEMP ("run_test_jira_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
Start-Transcript -Path $transcriptPath -Force | Out-Null
try {
    ..\run_tc.bat $testArgs $Profile
} finally {
    Stop-Transcript | Out-Null
}

# Extract issue keys from transcript (robust fallback)
$issueKeys = @()
if (Test-Path $transcriptPath) {
    $transcriptContent = Get-Content -Path $transcriptPath -Raw -ErrorAction SilentlyContinue
    if ($transcriptContent) {
        # Primary pattern: explicit creation line
        $primaryMatches = $transcriptContent | Select-String -Pattern "Created Jira issue (DEV-\d+)" -AllMatches
        if ($primaryMatches) {
            $primary = $primaryMatches.Matches | ForEach-Object { $_.Groups[1].Value }
        } else {
            $primary = @()
        }
        
        # Fallback: any DEV-123 style keys present in reporter lines
        $fallbackMatches = $transcriptContent | Select-String -Pattern "\bDEV-\d+\b" -AllMatches
        if ($fallbackMatches) {
            $fallback = $fallbackMatches.Matches | ForEach-Object { $_.Value }
        } else {
            $fallback = @()
        }
        
        $issueKeys = @($primary + $fallback) | Select-Object -Unique
    }
}

if ($issueKeys.Count -gt 0) {
    Write-Host "[run_test] $($issueKeys.Count) issue(s) created: $($issueKeys -join ', ')"
    
    foreach ($testId in $testIdArray) {
        $testId = $testId.Trim()
        
        # Construir o nome do arquivo de report
        if ($testId -match "^\d+$") {
            $reportPattern = "TC$('{0:D3}' -f [int]$testId)_*.html"
        } else {
            $reportPattern = "$testId*.html"
        }
        
        # Encontrar o arquivo de report mais recente
        $reportFile = Get-ChildItem "..\reports\$reportPattern" -ErrorAction SilentlyContinue | 
                      Sort-Object LastWriteTime -Descending | 
                      Select-Object -First 1
        
        if ($reportFile) {
            # Attach to each created issue
            foreach ($issueKey in $issueKeys) {
                Write-Host "[run_test] Attaching $($reportFile.Name) to issue $issueKey..."
                
                # Preparar autenticação
                $auth = "$($env:JIRA_EMAIL):$($env:JIRA_API_TOKEN)"
                $base64Auth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($auth))
                
                $url = "$($env:JIRA_BASE_URL)/rest/api/2/issue/$issueKey/attachments"
                
                try {
                    # Preparar autenticação em base64
                    $auth = "$($env:JIRA_EMAIL):$($env:JIRA_API_TOKEN)"
                    $base64Auth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($auth))
                    
                    # Usar curl para fazer upload (mais confiável para multipart)
                    $curlArgs = @(
                        '-X', 'POST',
                        '-H', "Authorization: Basic $base64Auth",
                        '-H', 'X-Atlassian-Token: no-check',
                        '-F', "file=@`"$($reportFile.FullName)`"",
                        $url
                    )
                    
                    $output = curl.exe @curlArgs 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[run_test] Report attached to issue $issueKey"
                    } else {
                        Write-Host "[run_test] Warning: curl exit code $LASTEXITCODE"
                    }
                } catch {
                    Write-Host "[run_test] Attachment error: $_"
                }
            }
        } else {
            Write-Host "[run_test] Warning: Report not found for test $testId"
        }
    }
} else {
    Write-Host "[run_test] No issues were created (no failed checks)."
}

# Combine reports if requested
if ($CombineReports -and $testIdArray.Count -gt 1) {
    Write-Host "[run_test] Combining reports..."
    
    $reportsDir = Join-Path $PSScriptRoot 'reports'
    
    if (-not (Test-Path $reportsDir)) {
        Write-Host "[run_test] Warning: Reports directory not found: $reportsDir"
    } else {
        # Collect HTML report files but exclude previously generated combined reports
        $files = Get-ChildItem -Path $reportsDir -Filter '*.html' | Where-Object { $_.Name -notlike 'general_report*' } | Sort-Object Name
        
        if ($files.Count -eq 0) {
            Write-Host "[run_test] No HTML report files found to combine"
        } else {
            # Read head from first original report
            $firstContent = Get-Content -Raw -Path $files[0].FullName
            $headMatch = [regex]::Match($firstContent, '(?s)<head.*?</head>')
            if ($headMatch.Success) {
                $headHtml = $headMatch.Value
            } else {
                $headHtml = '<head><meta charset="utf-8" /><title>Combined Report</title></head>'
            }
            
            # Inject visual wrapper style
            $injectedStyle = @"
<style>
    body { font-family: Inter, -apple-system, 'Segoe UI', Roboto, sans-serif; background: #f3f4f6; color: #1f2937; }
    main { max-width: 1200px; margin: 2rem auto; background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.08); }
    .combined-report-item { margin-bottom: 2rem; }
    .combined-report-item h2 { margin: 0 0 0.75rem 0; padding: 0.25rem 0.5rem; background: #eef2ff; display: inline-block; border-radius: 6px; font-size: 1rem; }
    hr { border: none; border-top: 1px solid #e5e7eb; margin: 2rem 0; }
</style>
"@
            
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
            
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
            $timeFile = Join-Path $reportsDir ("general_report_$timestamp.html")
            Set-Content -Path $timeFile -Value $final -Encoding UTF8
            
            Write-Host "[run_test] Combined report created: $($timeFile | Split-Path -Leaf)"
        }
    }
}

Write-Host "[run_test] Done!"
