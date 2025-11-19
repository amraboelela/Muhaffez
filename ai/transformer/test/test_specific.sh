#!/bin/bash
# Run specific input tests for the Quran Seq2Seq model
# Mirrors the iOS AyaFinderMLModelTests

cd "$(dirname "$0")"

# Create backup of previous log if it exists
if [ -f log_specific.txt ]; then
    cp log_specific.txt log_backup.txt
    echo "Backed up previous log to log_backup.txt"
fi

echo "Running specific input tests..."
python3 test_specific_inputs.py > log_specific.txt
