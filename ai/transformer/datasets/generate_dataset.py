#!/usr/bin/env python3
"""
Generate training dataset from Quran text
Format: القاريء: [first 10 words] الاية: [first 5 words]
"""

import json
import sys
import os

# Add train directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../train'))

from seq2seq_model import load_quran_data


def normalize_arabic(text):
    """Normalize Arabic text - remove tashkeel and normalize hamza variants"""
    # Arabic diacritics
    arabic_diacritics = set([
        '\u064B', '\u064C', '\u064D', '\u064E', '\u064F',
        '\u0650', '\u0651', '\u0652', '\u0653', '\u0654',
        '\u0655', '\u0656', '\u0657', '\u0658', '\u0670',
    ])

    text = ''.join(c for c in text if c not in arabic_diacritics)

    # Normalize hamza variants
    hamza_map = {
        'إ': 'ا', 'أ': 'ا', 'آ': 'ا',
        'ؤ': 'و', 'ئ': 'ي'
    }

    for old, new in hamza_map.items():
        text = text.replace(old, new)

    return text


def generate_dataset(quran_path, output_path, max_input_words=10, max_output_words=5):
    """Generate dataset and save to JSON file"""

    print(f'Loading Quran data from: {quran_path}')
    ayat = load_quran_data(quran_path)
    print(f'Total ayat: {len(ayat)}')

    dataset = []

    for idx, ayah in enumerate(ayat):
        # Normalize and tokenize
        normalized = normalize_arabic(ayah)
        words = normalized.split()

        # Skip empty ayat
        if len(words) == 0:
            continue

        # Get first 10 words for input (or less if ayah is shorter)
        input_words = words[:max_input_words]

        # Get first 5 words for output (or less if ayah is shorter)
        output_words = words[:min(len(words), max_output_words)]

        # Create entry
        entry = {
            'ayah_index': idx + 1,
            'input': ' '.join(input_words),
            'output': ' '.join(output_words)
        }

        dataset.append(entry)

    # Save to JSON
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(dataset, f, ensure_ascii=False, indent=2)

    print(f'\n✓ Dataset generated successfully!')
    print(f'  Total entries: {len(dataset)}')
    print(f'  Saved to: {output_path}')

    # Show a few examples
    print(f'\nFirst 3 examples:')
    for i in range(min(3, len(dataset))):
        entry = dataset[i]
        print(f"\n  Ayah {entry['ayah_index']}:")
        print(f"    Input:  القاريء: {entry['input']}")
        print(f"    Output: الاية: {entry['output']}")


def main():
    quran_path = '../../../Muhaffez/quran-simple-min.txt'
    output_path = 'dataset_10_to_5.json'

    generate_dataset(quran_path, output_path, max_input_words=10, max_output_words=5)


if __name__ == '__main__':
    main()
