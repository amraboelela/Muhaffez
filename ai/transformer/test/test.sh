#!/bin/bash

cd "$(dirname "$0")"

echo "Testing Quran Seq2Seq Model..."
echo "========================================"
echo ""

python3 test.py

echo ""
echo "Testing completed!"
