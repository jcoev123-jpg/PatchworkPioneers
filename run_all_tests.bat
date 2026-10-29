@echo off
setlocal enabledelayedexpansion
set GODOT="C:\Users\jcoev\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
set PASS=0
set FAIL=0
for %%f in (tests\*_test.gd) do (
    %GODOT% --headless --path . -s "res://tests/%%~nxf" >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        set /a PASS+=1
    ) else (
        set /a FAIL+=1
        echo FAIL: %%f
    )
)
echo.
echo === SUMMARY ===
echo PASS: !PASS!
echo FAIL: !FAIL!
