#!/bin/bash
# Run specific input tests for the Quran Seq2Seq model
# Mirrors the iOS AyaFinderMLModelTests

cd "$(dirname "$0")"

echo "Running specific input tests..."
python3 test_specific_inputs.py > log_specific.txt
