# Supervisor: runs the relay and restarts it if the controller process itself crashes.
# A clean halt (cycle cap, STOP, pause, too many failures, planner done) exits 0 and is NOT restarted.
# Exit code 3 = a workflow-review patch is waiting (workflow\PATCH_*.diff): install it with checks, then restart.
#   powershell -ExecutionPolicy Bypass -File run_relay.ps1 [-Cycles 10]
param([int]$Cycles = 1000, [int]$MaxRestartsPerHour = 5, [int]$RollbackMinutes = 15)
# 2026-11-03: the watchdog's scheduled task runs BelowNormal and every child (controller, relay Chrome, Godot) inherited it, so Chrome starved under the lane test runs and ChatGPT pages timed out. Run Normal.
try { (Get-Process -Id $PID).PriorityClass = 'Normal' } catch {}
# Owner wants continuous runs (2026-10-06): never stop after a small cycle cap.
if ($Cycles -lt 1000) { $Cycles = 1000 }

$here = $PSScriptRoot
$GameName = "Game"
try { $gn = (Get-Content (Join-Path $PSScriptRoot "relay.json") -Raw -Encoding UTF8 | ConvertFrom-Json).game.name; if ($gn) { $GameName = $gn } } catch {}
$Host.UI.RawUI.WindowTitle = "$GameName relay - supervisor"
$restarts = New-Object System.Collections.Generic.List[datetime]
$patched = $null   # @{ At; Backup; File } of the last auto-installed patch, for the crash rollback
$code_files = "controller.py", "chatgpt_bridge.py", "prompts.py", "relay.json", "cloud.py", "playtest.py", "art_gen.py",
    "art_runner.py", "codex_lane.py", "lane_local.py", "run_tests.py", "run_relay.ps1", "health_check.py", "throughput.py"

function Say($msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] supervisor: $msg"
    Write-Host $line -ForegroundColor Magenta
    Add-Content -Path (Join-Path $here "logs\controller.log") -Value $line -Encoding utf8
}

function Restore-Backup($dir) {
    Get-ChildItem $dir -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $here $_.Name) -Force }
}

function Install-Patch($patch) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = Join-Path $here "setup_backups\pre-$($patch.BaseName)-$stamp"
    New-Item -ItemType Directory -Force $backup | Out-Null
    foreach ($n in $code_files) {
        $f = Join-Path $here $n
        if (Test-Path $f) { Copy-Item $f $backup }
    }
    $root = (& git -C $here rev-parse --show-toplevel).Trim()
    $prefix = (& git -C $here rev-parse --show-prefix).Trim().TrimEnd("/")
    & git -C $root apply --reverse --check "--directory=$prefix" $patch.FullName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Rename-Item $patch.FullName "$($patch.Name).applied"
        Say "$($patch.Name) was already installed"
        return
    }
    $out = & git -C $root apply --check "--directory=$prefix" $patch.FullName 2>&1
    if ($LASTEXITCODE -ne 0) {
        Rename-Item $patch.FullName "$($patch.Name).rejected"
        Say "$($patch.Name) does not apply to the current relay; set aside as .rejected ($out)"
        return
    }
    & git -C $root apply "--directory=$prefix" $patch.FullName
    $ok = $LASTEXITCODE -eq 0
    if ($ok) {
        foreach ($f in Get-ChildItem $here -Filter *.py -File) {
            & python -m py_compile $f.FullName
            if ($LASTEXITCODE -ne 0) { $ok = $false; break }
        }
    }
    if ($ok) {
        & python -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" (Join-Path $here "relay.json")
        $ok = $LASTEXITCODE -eq 0
    }
    if (-not $ok) {
        Restore-Backup $backup
        Rename-Item $patch.FullName "$($patch.Name).rejected"
        Say "$($patch.Name) broke a compile/config check; restored the backup and set it aside as .rejected"
        return
    }
    Rename-Item $patch.FullName "$($patch.Name).applied"
    $script:patched = @{ At = Get-Date; Backup = $backup; File = (Join-Path $patch.DirectoryName "$($patch.Name).applied") }
    Say "installed $($patch.Name) (backup: $backup); it is rolled back if the relay crashes within $RollbackMinutes min"
}

while ($true) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] starting relay (--cycles $Cycles)" -ForegroundColor Cyan
    Push-Location $here
    & python -u controller.py start --cycles $Cycles
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -eq 3) {
        $patch = Get-ChildItem (Join-Path $here "workflow") -Filter "PATCH_*.diff" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -First 1
        if ($patch) {
            Install-Patch $patch
            if (Test-Path $patch.FullName) {   # never loop on a patch that could not be marked as handled
                Say "could not mark $($patch.Name) as handled; turn auto_apply off or move the file, then restart"
                break
            }
        }
        continue
    }
    if ($code -eq 0) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] relay halted cleanly; supervisor exiting." -ForegroundColor Green
        & python (Join-Path $here "controller.py") status
        break
    }
    if (Test-Path (Join-Path $here "STOP")) { Write-Host "STOP set; not restarting."; break }
    if ($patched -and ((Get-Date) - $patched.At).TotalMinutes -lt $RollbackMinutes) {
        Restore-Backup $patched.Backup
        Rename-Item $patched.File ($patched.File -replace '\.applied$', '.rolledback')
        Say "relay crashed (code $code) within $RollbackMinutes min of an auto-installed patch; restored $($patched.Backup)"
        $patched = $null
    }
    $cutoff = (Get-Date).AddHours(-1)
    $restarts.RemoveAll({ param($t) $t -lt $cutoff }) | Out-Null
    if ($restarts.Count -ge $MaxRestartsPerHour) {
        Say "relay crashed $($restarts.Count) times in the last hour; giving up"
        break
    }
    $restarts.Add((Get-Date))
    # 2026-10-20: the 15:01 crash left nothing in controller.log; the exit code now does.
    Say "relay exited with code $code; restarting in 60s ($($restarts.Count)/$MaxRestartsPerHour this hour)"
    Start-Sleep 60
}
