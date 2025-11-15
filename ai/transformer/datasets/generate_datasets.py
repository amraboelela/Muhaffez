#!/usr/bin/env python3
"""
Generate dataset JSON files for different input word lengths
"""
import json
import sys
import os

# Add parent directories to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'train'))

from seq2seq_model import load_quran_data
from train import normalize_arabic

def generate_dataset(max_input_words, max_output_words=5):
    """Generate dataset with specified input/output word counts"""

    # Load Quran data
    quran_path = '../../../Muhaffez/quran-simple-min.txt'
    ayat = load_quran_data(quran_path)

    dataset = []

    for idx, ayah in enumerate(ayat, start=1):
        # Normalize and split into words
        normalized = normalize_arabic(ayah)
        words = normalized.split()

        # Get input words (up to max_input_words)
        input_words = words[:min(len(words), max_input_words)]

        # Get output words (up to max_output_words)
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

    print("\nAll datasets generated successfully!")

if __name__ == "__main__":
    main()
