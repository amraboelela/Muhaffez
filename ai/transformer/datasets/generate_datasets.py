#!/usr/bin/env python3
"""
Generate dataset JSON files for different input word lengths
Uses Android normalized Quran file (canonical normalization)
"""
import json
import sys
import os

# Add parent directories to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))

from seq2seq_model import load_quran_data


def generate_dataset(max_input_words, max_output_words=5, skip_first=0):
    """Generate dataset with specified input/output word counts

    Args:
        max_input_words: Number of words for input
        max_output_words: Number of words for output
        skip_first: Number of words to skip at the beginning for input (default: 0)
    """

    # Load Android normalized Quran data (already normalized)
    quran_path = '/Users/amraboelela/develop/android/AndroidArabicWhisper/muhaffez-whisper/datasets/quran-simple-norm.txt'
    ayat = load_quran_data(quran_path)

    dataset = []

    for idx, ayah in enumerate(ayat, start=1):
        # Split into words (already normalized)
        words = ayah.split()

        # If ayah has ≤3 words total, don't skip - use original words
        if len(words) <= 3:
            input_words = words[:min(len(words), max_input_words)]
        else:
            # Ayah has >3 words, proceed with skipping
            start_idx = skip_first
            end_idx = start_idx + max_input_words
            input_words = words[start_idx:min(len(words), end_idx)]

        # Get output words (always from the beginning)
        output_words = words[:min(len(words), max_output_words)]

        # Create entry
        entry = {
            "ayah_index": idx,
            "input": " ".join(input_words),
            "output": " ".join(output_words)
        }

        dataset.append(entry)

    return dataset


def generate_dataset_skip_position(max_input_words, max_output_words=5, skip_position=0):
    """Generate dataset with a specific word position skipped

    Args:
        max_input_words: Number of words for input (after skipping)
        max_output_words: Number of words for output
        skip_position: Position of word to skip (0-indexed, e.g., 1 = skip 2nd word)
    """

    # Load Android normalized Quran data
    quran_path = '/Users/amraboelela/develop/android/AndroidArabicWhisper/muhaffez-whisper/datasets/quran-simple-norm.txt'
    ayat = load_quran_data(quran_path)

    dataset = []

    for idx, ayah in enumerate(ayat, start=1):
        # Split into words (already normalized)
        words = ayah.split()

        # If ayah has ≤3 words total, don't skip - use original words
        if len(words) <= 3:
            input_words = words[:min(len(words), max_input_words)]
        else:
            # Ayah has >3 words, skip the word at skip_position
            # Take words before skip position
            before_skip = words[0:skip_position]
            # Calculate how many more words we need
            remaining = max_input_words - len(before_skip)
            # Take words after skip position
            after_skip = words[skip_position+1:min(len(words), skip_position+1+remaining)]
            input_words = before_skip + after_skip

        # Get output words (always from the beginning)
        output_words = words[:min(len(words), max_output_words)]

        # Create entry
        entry = {
            "ayah_index": idx,
            "input": " ".join(input_words),
            "output": " ".join(output_words)
        }

        dataset.append(entry)

    return dataset

def main():
    """Generate datasets for different input word counts"""

    output_words = 5

    # Generate datasets for input words from 10 down to 3
    for input_words in range(10, 2, -1):
        print(f"Generating dataset_{input_words}_to_{output_words}.json...")

        dataset = generate_dataset(input_words, output_words)

        output_file = f"dataset_{input_words}_to_{output_words}.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(dataset, f, ensure_ascii=False, indent=2)

        print(f"  ✓ Created {output_file} with {len(dataset)} entries")

    # Generate datasets with first word skipped (from 10 down to 4)
    # For dataset_N_to_5_1.json: take (N-1) words starting from position 1
    # If result has ≤3 words, use original words instead
    print("\nGenerating datasets with first word skipped...")
    for input_words in range(10, 3, -1):  # 10 down to 4
        print(f"Generating dataset_{input_words}_to_{output_words}_1.json...")

        # Take (input_words - 1) words, starting from position 1 (skip first)
        dataset = generate_dataset(input_words - 1, output_words, skip_first=1)

        output_file = f"dataset_{input_words}_to_{output_words}_1.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(dataset, f, ensure_ascii=False, indent=2)

        print(f"  ✓ Created {output_file} with {len(dataset)} entries")

    # Generate datasets with second word skipped (from 10 down to 4)
    # For dataset_N_to_5_2.json: take (N-1) words, skipping position 1 (2nd word)
    # If ayah has ≤3 words, use original words instead
    print("\nGenerating datasets with second word skipped...")
    for input_words in range(10, 3, -1):  # 10 down to 4
        print(f"Generating dataset_{input_words}_to_{output_words}_2.json...")

        # Take (input_words - 1) words, skipping position 1 (skip 2nd word)
        dataset = generate_dataset_skip_position(input_words - 1, output_words, skip_position=1)

        output_file = f"dataset_{input_words}_to_{output_words}_2.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(dataset, f, ensure_ascii=False, indent=2)

        print(f"  ✓ Created {output_file} with {len(dataset)} entries")

    print("\nAll datasets generated successfully!")

if __name__ == "__main__":
    main()
