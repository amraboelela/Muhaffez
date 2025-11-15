#!/bin/bash

cd "$(dirname "$0")"

LOG_FILE="log.txt"

echo "Starting Quran Seq2Seq Model Training..."
echo "========================================"
echo ""
echo "Training in progress... (check $LOG_FILE for details)"
echo ""

# Backup existing log file before starting
if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
    cp "$LOG_FILE" "log_backup.txt"
    echo "✓ Log backup created: log_backup.txt"
fi

# Run training and capture output
python3 train.py > "$LOG_FILE" 2>&1

# Check if training completed successfully
if [ $? -eq 0 ]; then
    echo "✓ Training completed successfully!"
    echo ""

    # Extract and display summary
    echo "Summary:"
    echo "--------"
    grep -E "^(Vocabulary size|✓ Total ayat|Total parameters|Starting training|Epoch [0-9]+ \||✓ Early stopping|✓ Best accuracy|✓ Best loss|✓ Total time|FINAL_ACCURACY|FINAL_LOSS)" "$LOG_FILE" | tail -20
    echo ""
    echo "Full details available in: $LOG_FILE"
else
    echo "❌ Training failed! Check $LOG_FILE for details"
    tail -20 "$LOG_FILE"
fi

