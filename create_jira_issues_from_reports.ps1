# create_jira_issues_from_reports.ps1
# Scans reports/ folder for HTML files and creates Jira issues for any tests with failed checks
# Usage: .\create_jira_issues_from_reports.ps1
# Run after executing tests with run_all_tests.bat or run_tc.bat

param(
    [string]$ReportsDir = ".\reports",
    [string]$TestsDir = ".\tests"
)

# Check if Jira env vars are set
if (-not ($env:JIRA_BASE_URL -and $env:JIRA_EMAIL -and $env:JIRA_API_TOKEN -and $env:JIRA_PROJECT_KEY)) {
    Write-Host "[ERROR] Jira environment variables not set. Run ..\set_jira_env.bat first." -ForegroundColor Red
    exit 1
}

function ConvertTo-Base64($String) {
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($String)
    return [Convert]::ToBase64String($Bytes)
}

function Get-BasicAuthHeader {
    $Auth = "$($env:JIRA_EMAIL):$($env:JIRA_API_TOKEN)"
    return "Basic $(ConvertTo-Base64 -String $Auth)"
}

function Parse-HtmlReportForChecks {
    param([string]$HtmlFile)
    
    $Content = Get-Content $HtmlFile -Raw
    $FailedChecks = @()
    
    # Look for table rows with failed checks (red cells)
    # Pattern: <td>check_name</td> ... <td class="failed">8</td> (failures column)
    
    # Simpler approach: find all check rows and extract pass/fail counts
    $Pattern = '<td>([^<]+)</td>\s*<td[^>]*>(\d+)</td>\s*<td[^>]*class="failed"[^>]*>(\d+)</td>\s*<td[^>]*>([0-9.]+)</td>'
    
    $Matches = [regex]::Matches($Content, $Pattern)
    
    foreach ($Match in $Matches) {
        $CheckName = $Match.Groups[1].Value.Trim()
        $Passes = [int]$Match.Groups[2].Value
        $Failures = [int]$Match.Groups[3].Value
        $PassPercent = $Match.Groups[4].Value
        
        if ($Failures -gt 0) {
            $FailedChecks += @{
                Name = $CheckName
                Passes = $Passes
                Failures = $Failures
                PassPercent = $PassPercent
            }
        }
    }
    
    return $FailedChecks
}

function Create-JiraIssue {
    param(
        [string]$TestName,
        [array]$FailedChecks,
        [int]$TotalFailed,
        [int]$TotalChecks
    )
    
    if ($FailedChecks.Count -eq 0) {
        return $null
    }
    
    $BaseUrl = $env:JIRA_BASE_URL.TrimEnd('/')
    $Url = "$BaseUrl/rest/api/2/issue"
    
    # Format failed checks table
    $ChecksTable = "CHECK NAME | PASSES | FAILURES | % PASS`n"
    $ChecksTable += "---|---|---|---`n"
    foreach ($Check in $FailedChecks) {
        $ChecksTable += "$($Check.Name) | $($Check.Passes) | $($Check.Failures) | $($Check.PassPercent)%`n"
    }
    
    $Description = @"
Automated bug created by k6 (post-execution scan).

h4. Test Information
Test: $TestName
Total Failed Checks: $TotalFailed / $TotalChecks

h4. Failed Checks Details
{panel:bgColor=#f2f2f2}
$ChecksTable
{panel}
"@
    
    $Payload = @{
        fields = @{
            project = @{ key = $env:JIRA_PROJECT_KEY }
            issuetype = @{ name = "Bug" }
            summary = "k6 failure: $TestName - $TotalFailed checks failed"
            description = $Description
        }
    } | ConvertTo-Json -Depth 5
    
    $Headers = @{
        Authorization = Get-BasicAuthHeader
        Accept = "application/json"
        "Content-Type" = "application/json"
    }
    
    try {
        Write-Host "[jira-scanner] Creating issue for $TestName..." -ForegroundColor Cyan
        $Response = Invoke-RestMethod -Uri $Url -Method Post -Body $Payload -Headers $Headers -ErrorAction Stop
        Write-Host "[jira-scanner] Created Jira issue $($Response.key)" -ForegroundColor Green
        return $Response.key
    } catch {
        Write-Host "[jira-scanner] Failed to create issue: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Main
Write-Host "[jira-scanner] Scanning reports for failed checks..." -ForegroundColor Cyan

if (-not (Test-Path $ReportsDir)) {
    Write-Host "[ERROR] Reports directory not found: $ReportsDir" -ForegroundColor Red
    exit 1
}

$HtmlFiles = Get-ChildItem -Path $ReportsDir -Filter "*.html" | Sort-Object Name
$IssuesCreated = 0

foreach ($File in $HtmlFiles) {
    $TestName = $File.BaseName
    Write-Host "`nProcessing: $TestName"
    
    $FailedChecks = Parse-HtmlReportForChecks -HtmlFile $File.FullName
    
    if ($FailedChecks.Count -gt 0) {
        $TotalFailed = ($FailedChecks | Measure-Object -Property Failures -Sum).Sum
        $TotalPasses = ($FailedChecks | Measure-Object -Property Passes -Sum).Sum
        $TotalChecks = $TotalFailed + $TotalPasses
        
        Write-Host "  Found $($FailedChecks.Count) failing checks ($TotalFailed failures)" -ForegroundColor Yellow
        
        $IssueKey = Create-JiraIssue -TestName $TestName -FailedChecks $FailedChecks -TotalFailed $TotalFailed -TotalChecks $TotalChecks
        if ($IssueKey) {
            $IssuesCreated++
        }
    } else {
        Write-Host "  No failed checks" -ForegroundColor Green
    }
}

Write-Host "`n[jira-scanner] Complete. Created $IssuesCreated Jira issue(s)." -ForegroundColor Cyan
