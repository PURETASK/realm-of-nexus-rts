#!/bin/bash
# Headless smoke test with a timeout and a compact error summary.
#   usage: GODOT=/path/to/godot.exe tools/run_check.sh [sim_seconds] [timeout_s]
cd "$(dirname "$0")/.."
python tools/gen_class_cache.py
G="${GODOT:-godot}"
LOG="${TMPDIR:-/tmp}/nexus_sim_run.log"
SIM_SECONDS=${1:-60} timeout ${2:-240} "$G" --headless --path . -s tools/sim_test.gd > "$LOG" 2>&1
echo "exit=$? lines=$(wc -l < "$LOG") log=$LOG"
echo "--- parse/script errors (deduped):"
grep -A1 "SCRIPT ERROR" "$LOG" | grep -v "^--" | paste - - | sed 's/SCRIPT ERROR: //; s/ *at: [A-Za-z_:]* (//; s/)$//' | grep -v "Cannot infer the type" | sort -u | head -60
echo "--- runtime errors:"
grep -B1 -A2 "^ERROR\|^USER ERROR\|^SCRIPT ERROR: [^P]" "$LOG" | grep -v "SCRIPT ERROR: Parse\|ObjectDB\|Resources still\|cleanup\|resource.cpp" | head -40
echo "--- progress/tail:"
grep "^\[" "$LOG" | tail -8
echo "--- result:"
cat sim_result.txt 2>/dev/null
