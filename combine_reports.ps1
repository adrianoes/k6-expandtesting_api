# combine_reports.ps1
# Generate a combined HTML report from individual reports in /reports

$root = $PSScriptRoot
$reportsDir = Join-Path $root 'reports'
$testsDir = Join-Path $root 'tests'

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
        Write-Host "[combine] Warning: Reports directory not found: $reportsDir"
        return
    }

    $files = Get-ChildItem -Path $reportsDir -Filter '*.html' | Where-Object { $_.Name -notlike 'general_report*' } | Sort-Object Name
    if ($files.Count -eq 0) {
        Write-Host "[combine] No HTML report files found to combine"
        return
    }

    $firstContent = Get-Content -Raw -Path $files[0].FullName
    $headMatch = [regex]::Match($firstContent, "(?s)<head.*?</head>")
    if ($headMatch.Success) {
        $headHtml = $headMatch.Value
    } else {
        $headHtml = '<head><meta charset="utf-8" /><title>Combined Report</title></head>'
    }

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

        $prefix = "r${i}_"

        $inner = [regex]::Replace($inner, 'id="([^"]+)"', { param($mm) 'id="' + $prefix + $mm.Groups[1].Value + '"' })
        $inner = [regex]::Replace($inner, 'for="([^"]+)"', { param($mm) 'for="' + $prefix + $mm.Groups[1].Value + '"' })
        $inner = [regex]::Replace($inner, 'name="([^"]+)"', { param($mm) 'name="' + $prefix + $mm.Groups[1].Value + '"' })
        $inner = [regex]::Replace($inner, 'aria-controls="([^"]+)"', { param($mm) 'aria-controls="' + $prefix + $mm.Groups[1].Value + '"' })
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

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
    $timeFile = Join-Path $reportsDir ("general_report_$timestamp.html")
    Set-Content -Path $timeFile -Value $final -Encoding UTF8

    Write-Host "[combine] Combined report created: $($timeFile | Split-Path -Leaf)"
}

Combine-Reports
