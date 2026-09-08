@echo off
rem Runs the headless Godot smoke test.  Usage:  run_test.bat "C:\path\to\Godot_v4.x_win64.exe"
rem Without an argument it looks for "godot" on PATH.
setlocal
set GODOT=%~1
if "%GODOT%"=="" set GODOT=godot
cd /d "%~dp0"
python tools\gen_class_cache.py
"%GODOT%" --headless --path . -s tools/sim_test.gd
echo.
echo ---- sim_result.txt ----
if exist sim_result.txt type sim_result.txt
endlocal
