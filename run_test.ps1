# run_test_and_attach_report.ps1
# Executa o teste k6 e anexa automaticamente o report HTML à issue do Jira criada
# Usage: . ..\run_test_and_attach_report.ps1 -TestIds 001,010 -Profile smoke

param(
    [Parameter(Mandatory=$false)][string]$TestIds,
    [Parameter(Mandatory=$false)][switch]$AllTests,
    [Parameter(Mandatory=$false)][string]$Profile = "smoke"
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
    $testIdArray = ($TestIds -split ',') | ForEach-Object { $_.Trim() }
    $testArgs = $TestIds
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
        $primary = ($transcriptContent | Select-String -Pattern "Created Jira issue (DEV-\d+)").Matches | ForEach-Object { $_.Groups[1].Value }
        # Fallback: any DEV-123 style keys present in reporter lines
        $fallback = ($transcriptContent | Select-String -Pattern "\bDEV-\d+\b").Matches | ForEach-Object { $_.Value }
        $issueKeys = @($primary + $fallback) | Select-Object -Unique
    }
}

if ($issueKeys.Count -eq 0) {
    Write-Host "[run_test] No issues were created (no failed checks)."
    exit 0
}

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

Write-Host "[run_test] Done!"
