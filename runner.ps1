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
$dashboardReportsDir = Join-Path $PSScriptRoot 'reports_dashboard'
if ($openDashboard -and -not (Test-Path $dashboardReportsDir)) {
    New-Item -ItemType Directory -Path $dashboardReportsDir | Out-Null
}

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
    $normalizedName = $baseName -replace '_\d{8}_\d{6}$', ''
    if ($normalizedName) {
        $baseName = $normalizedName
    }
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
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $timeFile = Join-Path $reportsDir ("general_report_$timestamp.html")
    Set-Content -Path $timeFile -Value $final -Encoding UTF8

    Write-Host "[scripts] Combined report created: $($timeFile | Split-Path -Leaf)"
}

function Format-DashboardLabel($timestamp) {
        if ($timestamp -match '^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$') {
                return "$($matches[1])-$($matches[2])-$($matches[3]) $($matches[4]):$($matches[5]):$($matches[6])"
        }
        return $timestamp
}

function Get-DashboardData($content) {
        $match = [regex]::Match($content, '(?s)<script id="data"[^>]*>(.*?)</script>')
        if (-not $match.Success) {
                return $null
        }
        return $match.Groups[1].Value.Trim()
}

function Get-DashboardGroups {
        if (-not (Test-Path $dashboardReportsDir)) {
                Write-Host "[scripts] Warning: Dashboard reports directory not found: $dashboardReportsDir"
                return @()
        }

        $items = Get-ChildItem -Path $dashboardReportsDir -Filter '*_dashboard_*.html' | ForEach-Object {
                if ($_.Name -match '^(?<test>.+)_dashboard_(?<ts>\d{8}_\d{6})\.html$') {
                        [pscustomobject]@{
                                File = $_
                                Test = $matches['test']
                                Timestamp = $matches['ts']
                        }
                }
        }

        return $items | Group-Object Test
}

function Combine-DashboardReport($group) {
    $desiredRuns = 2
    $runs = $group.Group | Sort-Object Timestamp | Select-Object -Last $desiredRuns
    if ($runs.Count -lt $desiredRuns) {
        Write-Host "[scripts] Skipping $($group.Name): expected $desiredRuns dashboard runs, found $($runs.Count)"
        return
    }

        $templateContent = Get-Content -Raw -Path $runs[0].File.FullName
        $dataBlocks = @()
        foreach ($run in $runs) {
                $content = Get-Content -Raw -Path $run.File.FullName
                $dataBlock = Get-DashboardData $content
                if (-not $dataBlock) {
                        Write-Host "[scripts] Warning: data block not found in $($run.File.Name)"
                        return
                }
                $dataBlocks += $dataBlock
        }

        $dataScript = "<script id=`"data`" type=`"application/json; charset=utf-8; gzip; base64`">$($dataBlocks[0])</script>"
        for ($i = 0; $i -lt $dataBlocks.Count; $i++) {
                $idx = $i + 1
                $dataScript += "`n<script id=`"data-run-$idx`" type=`"application/json; charset=utf-8; gzip; base64`">$($dataBlocks[$i])</script>"
        }

        $runLabels = $runs | ForEach-Object { Format-DashboardLabel $_.Timestamp }
        $runKeys = $runs | ForEach-Object { $_.Timestamp }
        $runLabelsJson = $runLabels | ConvertTo-Json -Compress
        $runKeysJson = $runKeys | ConvertTo-Json -Compress

        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $entryScript = @"
const bp=document.getElementById("root");
const runIds=["data-run-1","data-run-2"];
const runLabels=$runLabelsJson;
const runKeys=$runKeysJson;
const runSuffixes=["","__r1"];
    const combinedTimestamp="$timestamp";
const aggLabelMap={};

function mapAggregateLabel(key){
    return aggLabelMap[key]||key;
}

function parseMetricQuery(query,suffix){
    if(!query||query==="time") return query;
    const addSuffix=(name)=>{
        const braceIndex=name.indexOf("{");
        if(braceIndex===-1) return name+suffix;
        return name.slice(0,braceIndex)+suffix+name.slice(braceIndex);
    };
    const quoted = query.replace(/^\[("|')([^"']+)\1\]/,(m,q,name)=>"["+q+addSuffix(name)+q+"]");
    if(quoted!==query) return quoted;
    const bracketIndex=query.indexOf("[");
    if(bracketIndex!==-1) return query.slice(0,bracketIndex)+suffix+query.slice(bracketIndex);
    const braceIndex=query.indexOf("{");
    if(braceIndex!==-1) return query.slice(0,braceIndex)+suffix+query.slice(braceIndex);
    const dotIndex=query.indexOf(".");
    if(dotIndex!==-1) return query.slice(0,dotIndex)+suffix+query.slice(dotIndex);
    return query+suffix;
}

function formatTimestamp(ts){
    const match=ts.match(/^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$/);
    if(!match) return ts;
    return match[1]+"-"+match[2]+"-"+match[3]+"T"+match[4]+":"+match[5]+":"+match[6];
}

function patchMetricsUnit(metrics){
    const original=metrics.unit.bind(metrics);
    metrics.unit=(name,agg)=>{
        if(!agg) return original(name,agg);
        const base=agg.split("__")[0];
        return original(name,base);
    };
}

function patchSummaryHeader(){
    const desc=Object.getOwnPropertyDescriptor(fu.prototype,"header");
    if(!desc||!desc.get) return;
    Object.defineProperty(fu.prototype,"header",{
        get:function(){
            const base=desc.get.call(this);
            return base.map((item,idx)=>idx===0?item:mapAggregateLabel(item));
        }
    });
}

function buildMarkerPaths(){
    function pointsPath(shape){
        return (u,seriesIdx,idx0,idx1,filter)=>{
            const xVals=u.data[0];
            const yVals=u.data[seriesIdx];
            const xScale=u.series[0].scale;
            const yScale=u.series[seriesIdx].scale;
            const size=u.series[seriesIdx].points.size||6;
            const half=size/2;
            const path=new Path2D();
            const idxs=filter||[];
            const useAll=idxs.length===0;
            const start=idx0??0;
            const end=idx1??(xVals.length-1);
            const drawAt=(idx)=>{
                const xv=xVals[idx];
                const yv=yVals[idx];
                if(xv==null||yv==null) return;
                const x=u.valToPos(xv,xScale,true);
                const y=u.valToPos(yv,yScale,true);
                if(shape==="square"){ path.rect(x-half,y-half,size,size); return; }
                if(shape==="triangle"){
                    path.moveTo(x,y-half);
                    path.lineTo(x+half,y+half);
                    path.lineTo(x-half,y+half);
                    path.closePath();
                    return;
                }
                if(shape==="diamond"){
                    path.moveTo(x,y-half);
                    path.lineTo(x+half,y);
                    path.lineTo(x,y+half);
                    path.lineTo(x-half,y);
                    path.closePath();
                    return;
                }
            };
            if(useAll){
                for(let i=start;i<=end;i++){ drawAt(i); }
            } else {
                for(const i of idxs){ drawAt(i); }
            }
            return { stroke:path, fill:path, clip:null, flags:0 };
        };
    }
    return {
        square: pointsPath("square"),
        triangle: pointsPath("triangle"),
        diamond: pointsPath("diamond")
    };
}

function patchSeriesBuild(){
    const markerPaths=buildMarkerPaths();
    const original=v0.prototype.buildSeries;
    v0.prototype.buildSeries=function(seriesDefs,palette){
        const result=original.call(this,seriesDefs,palette);
        const defs=(seriesDefs&&seriesDefs[0]&&seriesDefs[0].query!=="time")
            ? [{query:"time"},...seriesDefs]
            : (seriesDefs||[]);
        for(let i=0;i<defs.length;i++){
            const def=defs[i];
            if(!def||!result[i]) continue;
            if(def.colorIndex!=null){
                const color=palette[def.colorIndex%palette.length];
                result[i].stroke=color.stroke;
                result[i].fill=color.fill;
            }
            if(def.marker){
                result[i].points={...result[i].points,show:true,size:6,paths:markerPaths[def.marker]};
            }
        }
        return result;
    };
}

function normalizeQueryName(query){
    if(!query) return query;
    const match=query.match(/^\[("|')(.+)\1\]$/);
    return match?match[2]:query;
}

function extractBaseName(query){
    const normalized=normalizeQueryName(query);
    const bracketIndex=normalized.indexOf("[");
    const dotIndex=normalized.indexOf(".");
    let endIndex=normalized.length;
    if(bracketIndex!==-1) endIndex=bracketIndex;
    else if(dotIndex!==-1) endIndex=dotIndex;
    return normalized.slice(0,endIndex);
}

function extractAggregates(query){
    if(!query) return [];
    const parenMatch=query.match(/\(([^\)]+)\)/);
    if(parenMatch){
        return parenMatch[1].split("||").map(s=>s.trim()).filter(Boolean);
    }
    const andMatch=query.match(/&&\s*([a-z0-9_]+)/i);
    if(andMatch) return [andMatch[1].trim()];
    return [];
}

function replaceAggregateFilter(query,agg){
    if(!query) return query;
    if(query.indexOf("(")!==-1) return query.replace(/\([^\)]*\)/,agg);
    return query.replace(/&&\s*[a-z0-9_]+/i,"&& "+agg);
}

function patchSamplesQuery(){
    const original=Gu.prototype.queryAll;
    Gu.prototype.queryAll=function(query){
        if(typeof query==="string" && query.indexOf("__r")!==-1){
            const baseName=extractBaseName(query);
            let vectors=this.lookup[baseName];
            if(!Array.isArray(vectors)){
                const values=this.values||{};
                vectors=Object.values(values).filter(v=>v&&(v.name===baseName||(v.metric&&v.metric.name===baseName)));
            }
            if(!Array.isArray(vectors)) return [];
            const dotIndex=query.indexOf(".");
            if(dotIndex!==-1){
                const agg=query.slice(dotIndex+1).trim();
                const filtered=vectors.filter(v=>v.aggregate===agg);
                if(filtered.length===0 && vectors.length>0 && vectors.every(v=>v.aggregate==null)) return vectors;
                return filtered;
            }
            const aggs=extractAggregates(query);
            if(aggs.length>0){
                const filtered=vectors.filter(v=>aggs.includes(v.aggregate));
                if(filtered.length===0 && vectors.length>0 && vectors.every(v=>v.aggregate==null)) return vectors;
                return filtered;
            }
            return vectors;
        }
        return original.call(this,query);
    };
}

function addMetrics(baseMetrics,runMetrics,suffix){
    for(const name in runMetrics.values){
        const meta=runMetrics.values[name];
        const newName=name+suffix;
        baseMetrics.values[newName]={...meta,name:newName};
        baseMetrics.names.push(newName);
    }
}

function addSamples(baseSamples,runSamples,baseMetrics,suffix){
    for(const key in runSamples.values){
        const vector=runSamples.values[key];
        const newName=vector.name+suffix;
        const newKey=vector.aggregate?(newName+"."+vector.aggregate):newName;
        const cloned={...vector,name:newName,metric:baseMetrics.values[newName]||vector.metric};
        baseSamples.values[newKey]=cloned;
        baseSamples.vectors[newKey]=cloned;
        if(!baseSamples.lookup[newName]) baseSamples.lookup[newName]=[];
        baseSamples.lookup[newName].push(cloned);
    }
}

function mergeSummary(baseSummary,runSummaries){
    for(const metricName in baseSummary.values){
        const baseRow=baseSummary.values[metricName];
        const newValues={};
        for(let runIdx=0;runIdx<runSummaries.length;runIdx++){
            const runRow=runSummaries[runIdx].values[metricName];
            if(!runRow) continue;
            for(const agg in runRow.values){
                const key=agg+"__"+(runIdx+1)+"__"+runKeys[runIdx];
                newValues[key]=runRow.values[agg];
                aggLabelMap[key]=agg+" - "+runLabels[runIdx];
            }
        }
        baseRow.values=newValues;
    }
    baseSummary.lookup=Object.values(baseSummary.values);
}

function normalizeTitle(value){
    return (value||"").toLowerCase().replace(/[^a-z0-9]+/g,"");
}

const overlayTitles=new Set([
    "httpperformanceoverview",
    "vus",
    "transferrate",
    "httprequestduration",
    "iterationduration",
    "httprequestfailedrate",
    "requestduration",
    "requestfailedrate",
    "requestrate",
    "requestwaiting",
    "tlshandshaking",
    "requestsending",
    "requestconnecting",
    "requestreceiving",
    "requestblocked"
]);

function expandPanelSeries(panel){
    if(panel.kind!=="chart"||!panel.series) return;
    const baseSeries=panel.series;
    const expanded=[];
    baseSeries.forEach((serie,idx)=>{
        if(serie.query==="time"){
            expanded.push(serie);
            return;
        }
        const aggList=extractAggregates(serie.query);
        const aggregates=aggList.length>0?aggList:[null];
        for(const agg of aggregates){
            const baseQuery=agg?replaceAggregateFilter(serie.query,agg):serie.query;
            for(let runIdx=0;runIdx<runSuffixes.length;runIdx++){
                const suffix=runSuffixes[runIdx];
                const query=parseMetricQuery(baseQuery,suffix);
                const marker=runIdx===0?"square":runIdx===1?"triangle":"diamond";
                const hasLegend=!!(serie.legend||serie.label);
                const legendBase=hasLegend?(serie.legend||serie.label):(extractBaseName(serie.query)||"value");
                const useAggLabel=!!(agg&&aggList.length>1);
                const legend=(useAggLabel?agg:legendBase)+" - "+runLabels[runIdx];
                const aggIndex=aggList.length>0?Math.max(0,aggList.indexOf(agg)):0;
                const colorBase=idx+1;
                const clone={...serie,query,legend,marker,colorIndex:colorBase+aggIndex};
                expanded.push(clone);
            }
        }
    });
    panel.series=expanded;
}

function patchConfig(config){
    config.tabs.forEach(tab=>{
        tab.sections.forEach(section=>{
            section.panels.forEach(panel=>{
                if(!overlayTitles.has(normalizeTitle(panel.title))) return;
                expandPanelSeries(panel);
            });
        });
    });
}

async function parseDigestFromTag(tagId){
    const dataEl=document.getElementById("data");
    const src=document.getElementById(tagId);
    if(!src) return null;
    dataEl.innerText=src.innerText;
    return await ec();
}

async function buildCombinedDigest(){
    const digests=[];
    for(const id of runIds){
        const digest=await parseDigestFromTag(id);
        if(digest) digests.push(digest);
    }
    if(digests.length===0) return null;
    const base=digests[0];
    patchMetricsUnit(base.metrics);
    patchSummaryHeader();
    patchSeriesBuild();
    patchSamplesQuery();

    for(let i=1;i<digests.length;i++){
        addMetrics(base.metrics,digests[i].metrics,runSuffixes[i]);
    }
    for(let i=1;i<digests.length;i++){
        addSamples(base.samples,digests[i].samples,base.metrics,runSuffixes[i]);
    }
    mergeSummary(base.summary,digests.map(d=>d.summary));
    if(combinedTimestamp){
        const parsed=formatTimestamp(combinedTimestamp);
        const dt=new Date(parsed);
        if(!isNaN(dt.getTime())) base.start=dt;
    }
    patchConfig(base.config);
    return base;
}

buildCombinedDigest().then(digest=>{
    if(digest){
        Qn(ne(yp,{digest:digest}),bp);
    }
});
"@

        $templateContent = [regex]::Replace($templateContent, '(?s)<script id="data"[^>]*>.*?</script>', $dataScript, 1)
        $templateContent = [regex]::Replace($templateContent, 'const bp=document\.getElementById\("root"\);\s*ec\(\)\.then\(e=>Qn\(ne\(yp,\{digest:e\}\),bp\)\);', $entryScript)
        $badMicro = ([char]0x00C2) + ([char]0x00B5) + 's'
        $micro = ([char]0x00B5) + 's'
        $templateContent = $templateContent -replace $badMicro, 'us'
        $templateContent = $templateContent -replace $micro, 'us'

        $outFile = Join-Path $dashboardReportsDir ("combined_dashboard_$($group.Name)_$timestamp.html")
        Set-Content -Path $outFile -Value $templateContent -Encoding UTF8

        Write-Host "[scripts] Combined dashboard created: $($outFile | Split-Path -Leaf)"
}

function Combine-DashboardReports {
        $groups = Get-DashboardGroups
        if ($groups.Count -eq 0) {
                Write-Host "[scripts] No dashboard reports found to combine"
                return
        }

        foreach ($group in $groups) {
                Combine-DashboardReport $group
        }
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

    if ($openDashboard) {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $dashboardReport = Join-Path $dashboardReportsDir ("${testName}_dashboard_${timestamp}.html")
        $env:K6_WEB_DASHBOARD_EXPORT = $dashboardReport
    }

    $k6Args = @('run')
    if ($openDashboard) {
        $k6Args += @('--out','web-dashboard')
    }
    $k6Args += @('--env',"K6_TEST_NAME=$testName")
    $k6Args += @('--env',"K6_TEST_TYPE=$profile")
    $k6Args += $file.FullName

    & k6 @k6Args

    if ($openDashboard) {
        Remove-Item Env:K6_WEB_DASHBOARD_EXPORT -ErrorAction SilentlyContinue
    }
}

if ($combineReports) {
    Write-Host "[scripts] Generating combined report..."
    Combine-Reports
    Combine-DashboardReports
}

Write-Host "[scripts] Done!"