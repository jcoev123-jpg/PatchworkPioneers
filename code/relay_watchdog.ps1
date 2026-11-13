# Relay watchdog (any game; the game is named in relay.json "game"): restarts the relay when it died WITHOUT a deliberate halt (e.g. the relay Chrome crashed,
# as at 2026-10-08 05:30). Uses no Claude. Install as a Windows scheduled task (see the bottom of this file).
# It never restarts after a STOP/PAUSE file or a "halted:" log line: those need the owner (or are the owner's choice).
param([string]$Relay = $PSScriptRoot,
      [int]$MaxRestartsPer2h = 3,
      [string]$PatchBranch = "claude/prompt-md-instructions-27ivw3",
      [string]$LogRepo = "",
      [int]$LogPushMinutes = 25,
      [string]$TaskName = "")
$GameName = "Game"
# 2026-11-03: the watchdog's scheduled task runs BelowNormal and every child (controller, relay Chrome, Godot) inherited it, so Chrome starved under the lane test runs and ChatGPT pages timed out. Run Normal.
try { (Get-Process -Id $PID).PriorityClass = 'Normal' } catch {}
try { $gn = (Get-Content (Join-Path $Relay "relay.json") -Raw -Encoding UTF8 | ConvertFrom-Json).game.name; if ($gn) { $GameName = $gn } } catch {}
if (-not $TaskName) { $TaskName = "$GameName relay watchdog" }
if (-not $LogRepo) { $LogRepo = "C:\" + (($GameName.ToLower() -replace "[^a-z0-9]+", "-").Trim("-")) + "-relay-logs" }

$wlog = Join-Path $Relay "logs\watchdog.log"
function Say($m) { "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m" | Add-Content -Path $wlog -Encoding utf8 }

# Owner 2026-10-08: every ~25 min push a redacted digest of the relay (log tails, state, lane logs, newest plan and
# playtest, current relay code) to the "relay-logs" branch so the cloud monitor can diagnose problems without the owner.
# Uses its own folder and repo ($LogRepo), never the game working tree. Each push replaces the branch (no history).
function Get-Redacted([string]$text) {
    $text = $text -replace '("[^"]*(key|token|secret|passw|cookie|auth|session)[^"]*"\s*:\s*)"[^"]*"', '$1"***"'
    $text = $text -replace '(sk-|ghp_|gho_|github_pat_|xox[bap]-|AIza)[A-Za-z0-9_\-]{10,}', '$1***'
    $text = $text -replace '(?i)(bearer\s+|password\s*[=:]\s*)\S+', '$1***'
    return $text
}
function Write-Digest([string]$name, [string]$text) {
    $p = Join-Path $LogRepo $name
    New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
    [IO.File]::WriteAllText($p, (Get-Redacted $text), (New-Object Text.UTF8Encoding $false))
}
function Get-Tail([string]$path, [int]$n) {
    if (Test-Path $path) { return ((Get-Content $path -Tail $n -Encoding UTF8 -ErrorAction SilentlyContinue) -join "`n") }
    return "(missing: $path)"
}
function Push-RelayLogs {
    $stamp = Join-Path $Relay "logs\logpush_last.txt"
    if ((Test-Path $stamp) -and ((Get-Date) - (Get-Item $stamp).LastWriteTime).TotalMinutes -lt $LogPushMinutes) { return }
    $root = (& git -C $Relay rev-parse --show-toplevel 2>$null)
    if (-not $root) { return }
    $root = $root.Trim()
    $env:GIT_TERMINAL_PROMPT = "0"; $env:GCM_INTERACTIVE = "never"
    if (-not (Test-Path (Join-Path $LogRepo ".git"))) {
        New-Item -ItemType Directory -Force $LogRepo | Out-Null
        & git -C $LogRepo init -q
        & git -C $LogRepo remote add origin (& git -C $root remote get-url origin).Trim()
        & git -C $LogRepo config core.autocrlf false
        & git -C $LogRepo config user.name "$GameName relay"
        & git -C $LogRepo config user.email "relay@localhost"
    }
    Get-ChildItem $LogRepo -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force

    $procs = Get-CimInstance Win32_Process
    $ctl = @($procs | Where-Object { $_.Name -like "python*" -and $_.CommandLine -match "controller\.py.*\bstart\b" })
    $sup = @($procs | Where-Object { $_.Name -eq "powershell.exe" -and $_.CommandLine -match "run_relay\.ps1" })
    $oc = @($procs | Where-Object { $_.CommandLine -match "opencode" -and $_.Name -notlike "powershell*" })
    $cdp = "down"; try { Invoke-WebRequest "http://127.0.0.1:9222/json/version" -TimeoutSec 5 -UseBasicParsing | Out-Null; $cdp = "up" } catch {}
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    $log = Join-Path $Relay "logs\controller.log"
    $age = if (Test-Path $log) { [int]((Get-Date) - (Get-Item $log).LastWriteTime).TotalMinutes } else { -1 }
    $drive = $null
    try { $drive = Get-PSDrive -Name (Split-Path $Relay -Qualifier -ErrorAction Stop).TrimEnd(':') -ErrorAction Stop } catch {}
    Write-Digest "status.txt" (@(
        "pushed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
        "controller processes: $($ctl.Count) $(($ctl | ForEach-Object { $_.ProcessId }) -join ',')",
        "supervisor processes: $($sup.Count)",
        "opencode processes: $($oc.Count)",
        "chrome cdp 9222: $cdp",
        "STOP: $(Test-Path (Join-Path $Relay 'STOP'))  PAUSE: $(Test-Path (Join-Path $Relay 'PAUSE'))",
        "watchdog task: $(if ($task) { $task.State } else { 'missing' })",
        "controller.log last write: $age min ago",
        "repo HEAD: $((& git -C $root log -1 --format='%h %ad %s' --date=iso) -join ' ')",
        "repo branch: $((& git -C $root rev-parse --abbrev-ref HEAD) -join ' ')",
        "repo dirty files: $(@(& git -C $root status --porcelain).Count)",
        "free disk GB: $(if ($drive) { [math]::Round($drive.Free / 1GB, 1) } else { '?' })"
    ) -join "`n")
    Write-Digest "controller.log" (Get-Tail $log 500)
    Write-Digest "watchdog.log" (Get-Tail (Join-Path $Relay "logs\watchdog.log") 100)
    foreach ($n in "state.json", "STATUS.md") {
        $f = Join-Path $Relay $n
        if (Test-Path $f) { Write-Digest $n (Get-Content $f -Raw -Encoding UTF8) }
    }
    # Running and recent lanes: their agent log tails.
    $lanes = @()
    try { $state = Get-Content (Join-Path $Relay "state.json") -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $state = $null }
    foreach ($k in "lane2", "lane3", "lane4", "lane5", "codex") {
        $t = if ($state) { $state."${k}_task" } else { $null }
        if (-not $t) { $lanes += "== ${k}: idle"; continue }
        $lanes += "== ${k}: $($t.title)"
        $lanes += "branch $($t.branch); started $(if ($t.started_ts) { [DateTimeOffset]::FromUnixTimeSeconds([int64]$t.started_ts).LocalDateTime } else { '?' }); finished $($t.finished); review $($t.review.verdict); fix_rounds $($t.fix_rounds); timed_out $($t.timed_out)"
        if ($t.log -and (Test-Path $t.log)) {
            $li = Get-Item $t.log
            $lanes += "log $($t.log) ($($li.Length) bytes, last write $($li.LastWriteTime))"
            $lanes += (Get-Tail $t.log 60)
        }
        if ($t.run_dir) {   # the lane's own report (SHOTS:/IMAGES: lines) and the screenshot-check verdict
            foreach ($n in "REPORT.md", "VISUAL_CHECK.md") {
                $f = Join-Path $t.run_dir $n
                if (Test-Path $f) { $lanes += "-- $n"; $lanes += (Get-Tail $f 40) }
            }
        }
    }
    Write-Digest "lanes.txt" ($lanes -join "`n")
    $wf = Join-Path $Relay "workflow"
    Write-Digest "workflow.txt" ((Get-ChildItem $wf -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime |
        ForEach-Object { "$($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))  $($_.Name)" }) -join "`n")
    $pt = Get-ChildItem (Join-Path $Relay "playtests") -Filter "PLAYTEST_*.md" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime | Select-Object -Last 1
    if ($pt) { Write-Digest "playtest_latest.md" (Get-Content $pt.FullName -Raw -Encoding UTF8) }
    foreach ($cd in @(Get-ChildItem (Join-Path $Relay "cycles") -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+$' } | Sort-Object Name | Select-Object -Last 2)) {
        foreach ($md in @(Get-ChildItem $cd.FullName -Filter "*.md" -File | Where-Object { $_.Length -lt 60KB })) {
            Write-Digest "cycles/$($cd.Name)/$($md.Name)" (Get-Content $md.FullName -Raw -Encoding UTF8)
        }
    }
    foreach ($n in "controller.py", "chatgpt_bridge.py", "prompts.py", "lane_local.py", "playtest.py", "cloud.py",
                   "codex_lane.py", "art_gen.py", "art_runner.py", "run_tests.py", "run_relay.ps1", "relay_watchdog.ps1", "throughput.py",
                   "relay.json", "LESSONS.md", "playtest_overlay/playtest/tour.gd") {
        $f = Join-Path $Relay $n
        if (Test-Path $f) { Write-Digest "code/$n" (Get-Content $f -Raw -Encoding UTF8) }
    }

    & git -C $LogRepo add -A
    & git -C $LogRepo update-ref -d HEAD 2>$null          # every push is a single fresh commit
    & git -C $LogRepo commit -q -m "relay digest $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    & git -C $LogRepo push -q -f origin HEAD:refs/heads/relay-logs 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Say "log digest push failed (exit $LASTEXITCODE)"; return }
    & git -C $LogRepo reflog expire --expire=now --all 2>$null
    & git -C $LogRepo gc -q --prune=now 2>$null
    Set-Content $stamp (Get-Date -Format o)
}
try { Push-RelayLogs } catch { Say "log digest failed: $_" }

if (Test-Path (Join-Path $Relay "STOP")) { exit 0 }

# Owner 2026-10-08: patches the cloud monitor pushes to .cloud/auto/ on its branch are dropped into workflow\, where the
# supervisor installs them at the next IDLE with its usual backup, checks and crash rollback. Each file is taken once.
function Get-CloudPatches {
    $root = (& git -C $Relay rev-parse --show-toplevel 2>$null)
    if (-not $root) { return }
    $root = $root.Trim()
    & git -C $root fetch -q origin $PatchBranch 2>$null
    if ($LASTEXITCODE -ne 0) { return }
    $seenFile = Join-Path $Relay "logs\auto_patches_seen.txt"
    $seen = @(Get-Content $seenFile -ErrorAction SilentlyContinue)
    $wf = Join-Path $Relay "workflow"
    New-Item -ItemType Directory -Force $wf | Out-Null
    foreach ($path in @(& git -C $root ls-tree --name-only "origin/$PatchBranch" ".cloud/auto/" 2>$null)) {
        if (-not ($path -match '^\.cloud/auto/(PATCH_[A-Za-z0-9_-]+\.diff)$')) { continue }
        $name = $Matches[1]
        $blob = (& git -C $root rev-parse "origin/${PatchBranch}:$path").Trim()
        if ($seen -contains "$name $blob") { continue }
        # A name the supervisor already handled (or still has queued) is never dropped again: it could not rename it.
        if (@(Get-ChildItem $wf -File -Filter "$name*" -ErrorAction SilentlyContinue).Count) {
            Say "cloud patch $name skipped: workflow\ already has a file with that name (rename the patch to resend it)"
            Add-Content $seenFile "$name $blob"
            continue
        }
        $text = & git -C $root cat-file blob $blob
        $targets = @($text | Where-Object { $_ -match '^diff --git ' })
        $bad = @($targets | Where-Object { $_ -match '\.\.|\s[ab]/[\\/]|:' })
        if (-not $targets.Count -or $bad.Count) {
            Say "cloud patch $name skipped: it must be a git diff with relay-relative paths"
        } else {
            $dest = Join-Path $wf $name
            # Redirect at the process level so the bytes stay exact (a PowerShell pipe would re-encode the patch).
            Start-Process git -ArgumentList "-C", "`"$root`"", "cat-file", "blob", $blob -RedirectStandardOutput $dest `
                -NoNewWindow -Wait
            Say "cloud patch $name ($($blob.Substring(0, 8))) queued for the supervisor"
        }
        Add-Content $seenFile "$name $blob"
    }
}
try { Get-CloudPatches } catch { Say "cloud patch check failed: $_" }

if (Test-Path (Join-Path $Relay "PAUSE")) { exit 0 }

$procs = Get-CimInstance Win32_Process
$controller = $procs | Where-Object { $_.Name -like "python*" -and $_.CommandLine -match "controller\.py.*\bstart\b" }
$supervisor = $procs | Where-Object { $_.Name -eq "powershell.exe" -and $_.CommandLine -match "run_relay\.ps1" }
if ($controller) { exit 0 }   # running; the ChatGPT bridge relaunches Chrome itself while the controller is alive

# Not running: was it a deliberate halt? After a halt the background playtest may still log a few lines, so look at
# the last "halted:" line and treat it as final when only playtest lines follow it. A "restarting the PC" halt
# (pc_restart, owner 2026-10-19) is not final: after the reboot and sign-in the relay resumes.
$tailLines = @(Get-Content (Join-Path $Relay "logs\controller.log") -Tail 40 -ErrorAction SilentlyContinue)
$last = $tailLines[-1]
$hi = -1
for ($i = 0; $i -lt $tailLines.Count; $i++) { if ($tailLines[$i] -match "halted:" -and $tailLines[$i] -notmatch "workflow patch|restarting the PC") { $hi = $i } }
$after = if ($hi -ge 0 -and $hi -lt $tailLines.Count - 1) { $tailLines[($hi + 1)..($tailLines.Count - 1)] } else { @() }
# Lane reviews, ChatGPT archive/smoke lines and the playtest keep logging while a halted controller winds down, so
# only a fresh start after the halt line makes it non-final (monitor 2026-10-23: two PAUSEs were undone this way).
$haltFinal = $hi -ge 0 -and -not ($after | Where-Object { $_ -match "controller started|=== cycle \d+ started" })
if ($haltFinal) {
    $last = $tailLines[$hi]
    if (-not (Test-Path (Join-Path $Relay "logs\watchdog_halt_seen")) -or
        (Get-Content (Join-Path $Relay "logs\watchdog_halt_seen") -Raw) -ne $last) {
        Say "relay is halted, not restarting (needs the owner): $last"
        Set-Content (Join-Path $Relay "logs\watchdog_halt_seen") $last -NoNewline
    }
    exit 0
}

# Restart budget, so a crash loop cannot run forever.
$hist = Join-Path $Relay "logs\watchdog_restarts.txt"
$cut = (Get-Date).AddHours(-2)
$recent = @(Get-Content $hist -ErrorAction SilentlyContinue | Where-Object { $_ -and [datetime]$_ -gt $cut })
if ($recent.Count -ge $MaxRestartsPer2h) { Say "relay down but $($recent.Count) restarts in 2 h already; leaving it"; exit 0 }

# 1) Relay Chrome (CDP 9222) must be up for ChatGPT.
$cdp = $false
try { Invoke-WebRequest "http://127.0.0.1:9222/json/version" -TimeoutSec 5 -UseBasicParsing | Out-Null; $cdp = $true } catch {}
if (-not $cdp) {
    $cfg = Get-Content (Join-Path $Relay "relay.json") -Raw | ConvertFrom-Json
    $argv = @($cfg.chatgpt.chrome_launch)
    Say "relay Chrome down; launching it"
    Start-Process -FilePath $argv[0] -ArgumentList $argv[1..($argv.Count - 1)] -WindowStyle Minimized
    for ($i = 0; $i -lt 30 -and -not $cdp; $i++) {
        Start-Sleep 2
        try { Invoke-WebRequest "http://127.0.0.1:9222/json/version" -TimeoutSec 3 -UseBasicParsing | Out-Null; $cdp = $true } catch {}
    }
    if (-not $cdp) { Say "Chrome did not come up on port 9222; will retry next run"; exit 1 }
    Start-Sleep 5
}

# 2) A supervisor without a controller is stuck: replace it.
$supervisor | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item (Join-Path $Relay "relay.lock") -ErrorAction SilentlyContinue
Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (Join-Path $Relay "run_relay.ps1") -WorkingDirectory $Relay -WindowStyle Hidden   # no console to click: QuickEdit freezes it
(Get-Date).ToString("o") | Add-Content $hist
Say "relay was down (last log: $last); restarted the supervisor"

<# Install (once, in PowerShell as yourself, not admin), after copying this file into the relay folder:
$r = "<this relay_v2 folder>"
$a = New-ScheduledTaskAction -Execute "conhost.exe" -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$r\relay_watchdog.ps1`""
$t = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName "<Game> relay watchdog" -Action $a -Trigger $t -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries)
# Remove:  Unregister-ScheduledTask -TaskName "<Game> relay watchdog" -Confirm:$false
#>
