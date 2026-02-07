# runner.ps1
# Unified test runner
# Execution options (exclusive): -all | -i <id> | -m-001-010-050 | -c-basic/-c-negative
# Support options (combinable): -bt -cr -g -tp-smoke|-tp-load|-tp-stress|-tp-spike|-tp-breakpoint|-tp-soak

$profiles = @('smoke','load','stress','spike','breakpoint','soak')
$categories = @('basic','negative')

$executionMode = $null
$singleId = $null
$multiIds = @()
$category = $null
$profile = 'smoke'
$enableJira = $false
$combineReports = $false
$openDashboard = $false

function Show-Usage {
    Write-Host "Usage examples:" 
    Write-Host "  . ..\\runner.ps1 -all"
    Write-Host "  . ..\\runner.ps1 -i 001 -tp-smoke -g -bt -cr"
    Write-Host "  . ..\\runner.ps1 -m-001-010-050 -tp-load -cr"
    Write-Host "  . ..\\runner.ps1 -c-basic -tp-smoke"
}

function Set-JiraEnv {
    if ($env:JIRA_BASE_URL -and $env:JIRA_EMAIL -and $env:JIRA_API_TOKEN -and $env:JIRA_PROJECT_KEY) {
        return $true
    }

    if ($env:JIRA_API_SECRETS) {
        $raw = $env:JIRA_API_SECRETS
        $pairs = $raw -split "[`r`n;]+" | Where-Object { $_ -and $_.Trim() -ne '' }
        foreach ($p in $pairs) {
            if ($p -match '^\s*([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $val = $matches[2].Trim()
                if ($key) {
                    Set-Item -Path "Env:$key" -Value $val
                }
            }
        }
    }

    $envScript = Join-Path $PSScriptRoot 'set_jira_env.ps1'
    if (Test-Path $envScript) {
        . $envScript
    }

    return ($env:JIRA_BASE_URL -and $env:JIRA_EMAIL -and $env:JIRA_API_TOKEN -and $env:JIRA_PROJECT_KEY)
}

# Parse arguments (order independent)
for ($i = 0; $i -lt $args.Count; $i++) {
    $token = $args[$i]
    $t = $token.ToLower()

    if ($t -eq '-all' -or $t -eq 'all') {
        if ($executionMode) { Write-Host "[scripts] Error: execution option already set ($executionMode)."; Show-Usage; exit 1 }
        $executionMode = 'all'
        continue
    }

    if ($t -eq '-i' -or $t -eq 'i') {
        if ($executionMode) { Write-Host "[scripts] Error: execution option already set ($executionMode)."; Show-Usage; exit 1 }
        if ($i + 1 -ge $args.Count) { Write-Host "[scripts] Error: -i requires a test id."; Show-Usage; exit 1 }
        $singleId = $args[$i + 1]
        $i++
        $executionMode = 'single'
        continue
    }

    if ($t -like '-m-*' -or $t -like 'm-*') {
        if ($executionMode) { Write-Host "[scripts] Error: execution option already set ($executionMode)."; Show-Usage; exit 1 }
        $listRaw = $t -replace '^-?m-',''
        $multiIds = $listRaw -split '-' | Where-Object { $_ -ne '' }
        if ($multiIds.Count -eq 0) { Write-Host "[scripts] Error: -m requires ids like -m-001-010."; Show-Usage; exit 1 }
        $executionMode = 'multi'
        continue
    }

    if ($t -eq '-m' -or $t -eq 'm') {
        if ($executionMode) { Write-Host "[scripts] Error: execution option already set ($executionMode)."; Show-Usage; exit 1 }
        $ids = @()
        $j = $i + 1
        while ($j -lt $args.Count) {
            $next = $args[$j]
            if ($next -match '^-') { break }
            $ids += $next
            $j++
        }
        if ($ids.Count -eq 0) { Write-Host "[scripts] Error: -m requires ids (e.g., -m 001 010 050)."; Show-Usage; exit 1 }
        $multiIds = $ids
        $executionMode = 'multi'
        $i = $j - 1
        continue
    }

    if ($t -like '-c-*' -or $t -like 'c-*') {
        if ($executionMode) { Write-Host "[scripts] Error: execution option already set ($executionMode)."; Show-Usage; exit 1 }
        $category = $t -replace '^-?c-',''
        if (-not $categories.Contains($category)) { Write-Host "[scripts] Error: invalid category '$category'."; Show-Usage; exit 1 }
        $executionMode = 'category'
        continue
    }

    if ($t -eq '-bt' -or $t -eq 'bt') { $enableJira = $true; continue }
    if ($t -eq '-cr' -or $t -eq 'cr') { $combineReports = $true; continue }
    if ($t -eq '-g' -or $t -eq 'g') { $openDashboard = $true; continue }

    if ($t -like '-tp-*' -or $t -like 'tp-*') {
        $profile = $t -replace '^-?tp-',''
        if (-not $profiles.Contains($profile)) { Write-Host "[scripts] Error: invalid profile '$profile'."; Show-Usage; exit 1 }
        continue
    }

    Write-Host "[scripts] Error: unknown option '$token'."
    Show-Usage
    exit 1
}

if (-not $executionMode) {
    $executionMode = 'all'
}

if ($enableJira) {
    if (-not (Set-JiraEnv)) {
        Write-Host "[scripts] Error: Jira variables not set. Configure set_jira_env.ps1 or JIRA_API_SECRETS."
        exit 1
    }
}

$testsDir = Join-Path $PSScriptRoot 'tests'
$reportsDir = Join-Path $PSScriptRoot 'reports'
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir | Out-Null }

function Resolve-TestsFromIds($ids) {
    $results = @()
    foreach ($id in $ids) {
        $idStr = $id.ToString().Trim()
        if ($idStr -match '^\d+$') {
            $pattern = "TC{0:D3}*.js" -f [int]$idStr
        } elseif ($idStr -match '^TC\d+') {
            $pattern = "$idStr*.js"
        } else {
            $pattern = "TC$idStr*.js"
        }
        $found = Get-ChildItem -Path $testsDir -Filter $pattern -ErrorAction SilentlyContinue | Sort-Object Name
        if ($found.Count -eq 0) {
            Write-Host "[scripts] Warning: no test files found for pattern $pattern"
        } else {
            $results += $found
        }
    }
    return $results | Select-Object -Unique
}

function Resolve-TestsByCategory($cat) {
    $files = Get-ChildItem -Path $testsDir -Filter 'TC*.js' | Sort-Object Name
    return $files | Where-Object { Select-String -Path $_.FullName -Pattern $cat -Quiet }
}

function Get-TestMetadata($baseName) {
    $meta = [ordered]@{ Id = $null; Categories = @() }
    if ($baseName -match '^TC(\d+)') {
        $meta.Id = $matches[1]
    }

    $testFile = Join-Path $testsDir ($baseName + '.js')
    if (Test-Path $testFile) {
        $content = Get-Content -Raw -Path $testFile
        if ($content -match '\bbasic\s*:\s*["'']true["'']') { $meta.Categories += 'basic' }
        if ($content -match '\bnegative\s*:\s*["'']true["'']') { $meta.Categories += 'negative' }
    }

    return $meta
}

function Combine-Reports {
    if (-not (Test-Path $reportsDir)) {
        Write-Host "[scripts] Warning: Reports directory not found: $reportsDir"
        return
    }

    # Collect HTML report files but exclude previously generated combined reports
    $files = Get-ChildItem -Path $reportsDir -Filter '*.html' | Where-Object { $_.Name -notlike 'general_report*' } | Sort-Object Name
    if ($files.Count -eq 0) {
        Write-Host "[scripts] No HTML report files found to combine"
        return
    }

    # Read head from first original report
    $firstContent = Get-Content -Raw -Path $files[0].FullName
    $headMatch = [regex]::Match($firstContent, "(?s)<head.*?</head>")
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
    .combined-report-filters { margin-bottom: 1.5rem; padding: 1rem; background: #f8fafc; border: 1px solid #e5e7eb; border-radius: 8px; }
    .combined-report-filters h2 { margin: 0 0 0.75rem 0; font-size: 1rem; }
    .filter-row { display: flex; flex-wrap: wrap; gap: 0.75rem 1rem; align-items: center; margin-bottom: 0.75rem; }
    .filter-row label { display: inline-flex; gap: 0.5rem; align-items: center; font-size: 0.9rem; }
    .filter-row input[type="text"] { min-width: 260px; padding: 0.35rem 0.5rem; border: 1px solid #d1d5db; border-radius: 6px; }
    .filter-actions { display: flex; gap: 0.5rem; }
    .filter-actions button { border: 1px solid #d1d5db; background: white; padding: 0.35rem 0.75rem; border-radius: 6px; cursor: pointer; }
    .combined-report-item { margin-bottom: 2rem; }
    .combined-report-item h2 { margin: 0 0 0.75rem 0; padding: 0.25rem 0.5rem; background: #eef2ff; display: inline-block; border-radius: 6px; font-size: 1rem; }
    hr { border: none; border-top: 1px solid #e5e7eb; margin: 2rem 0; }
</style>
"@

    # Attempt to insert injectedStyle into the head HTML
    if ($headHtml -match "(?i)</head>") {
        $headHtml = $headHtml -replace "(?i)</head>", "$injectedStyle`n</head>"
    } else {
        $headHtml = "$headHtml`n$injectedStyle"
    }

    $bodies = @()
    $i = 0
    foreach ($f in $files) {
        $i++
        $c = Get-Content -Raw -Path $f.FullName
        $m = [regex]::Match($c, "(?s)<body.*?>(.*?)</body>")
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

                $meta = Get-TestMetadata $f.BaseName
                $testId = if ($meta.Id) { $meta.Id } else { '' }
                $categoryAttr = ($meta.Categories -join ',')

                $section = "<section class='combined-report-item' id='${prefix}section' data-test-id='${testId}' data-category='${categoryAttr}'>`n<h2>$($f.BaseName)</h2>`n" + $inner + "`n</section>"
        $bodies += $section
    }

        $filterHtml = @"
<section class='combined-report-filters'>
    <h2>Filters</h2>
    <div class='filter-row'>
        <label for='filterTestIds'>Test ID filter (ex: 001 or 001,010,050)</label>
        <input id='filterTestIds' type='text' placeholder='001,010,050' />
    </div>
    <div class='filter-row'>
        <span>Test category filter</span>
        <label><input type='checkbox' id='filterCatBasic' /> basic</label>
        <label><input type='checkbox' id='filterCatNegative' /> negative</label>
    </div>
    <div class='filter-actions'>
        <button id='filterClear' type='button'>Clear</button>
    </div>
</section>
"@

        $combinedBody = $filterHtml + "`n" + ($bodies -join "`n<hr/>`n")
        $filterScript = @"
<script>
(function () {
    const sections = Array.from(document.querySelectorAll('.combined-report-item'));
    const input = document.getElementById('filterTestIds');
    const basic = document.getElementById('filterCatBasic');
    const negative = document.getElementById('filterCatNegative');
    const clearBtn = document.getElementById('filterClear');

    function parseIds(value) {
        if (!value) return [];
        const raw = value.split(/[^0-9]+/).filter(Boolean);
        return raw.map(v => String(parseInt(v, 10)).padStart(3, '0'));
    }

    function applyFilters() {
        const ids = parseIds(input.value);
        const categories = [];
        if (basic.checked) categories.push('basic');
        if (negative.checked) categories.push('negative');

        const hasIds = ids.length > 0;
        const hasCategories = categories.length > 0;

        sections.forEach(section => {
            const testId = section.dataset.testId || '';
            const testCategories = (section.dataset.category || '').split(',').filter(Boolean);

            let visible = true;
            if (hasIds) {
                visible = ids.includes(testId);
            }
            if (visible && hasCategories) {
                visible = testCategories.some(cat => categories.includes(cat));
            }

            if (!hasIds && !hasCategories) {
                visible = true;
            }

            section.style.display = visible ? '' : 'none';
        });
    }

    input.addEventListener('input', applyFilters);
    basic.addEventListener('change', applyFilters);
    negative.addEventListener('change', applyFilters);
    clearBtn.addEventListener('click', () => {
        input.value = '';
        basic.checked = false;
        negative.checked = false;
        applyFilters();
    });
})();
</script>
"@

        $final = "<!DOCTYPE html>`n<html>`n$headHtml`n<body>`n<main>`n$combinedBody`n</main>`n$filterScript`n</body>`n</html>"

    # Only write timestamped output as requested by the user
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
    $timeFile = Join-Path $reportsDir ("general_report_$timestamp.html")
    Set-Content -Path $timeFile -Value $final -Encoding UTF8

    Write-Host "[scripts] Combined report created: $($timeFile | Split-Path -Leaf)"
}

$testFiles = @()
if ($executionMode -eq 'all') {
    $testFiles = Get-ChildItem -Path $testsDir -Filter 'TC*.js' | Sort-Object Name
} elseif ($executionMode -eq 'single') {
    $testFiles = Resolve-TestsFromIds @($singleId)
} elseif ($executionMode -eq 'multi') {
    $testFiles = Resolve-TestsFromIds $multiIds
} elseif ($executionMode -eq 'category') {
    $testFiles = Resolve-TestsByCategory $category
}

if ($testFiles.Count -eq 0) {
    Write-Host "[scripts] Error: no test files to run."
    exit 1
}

if ($openDashboard) {
    Start-Process "http://localhost:5665"
}

Write-Host "[scripts] Running $($testFiles.Count) test(s) with profile: $profile"

foreach ($file in $testFiles) {
    $testName = $file.BaseName
    Write-Host "[scripts] Running $($file.Name)"

    $k6Args = @('run')
    if ($openDashboard) {
        $k6Args += @('--out','web-dashboard')
    }
    $k6Args += @('--env',"K6_TEST_NAME=$testName")
    $k6Args += @('--env',"K6_TEST_TYPE=$profile")
    $k6Args += $file.FullName

    & k6 @k6Args
}

if ($combineReports) {
    Write-Host "[scripts] Generating combined report..."
    Combine-Reports
}

Write-Host "[scripts] Done!"