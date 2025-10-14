import json
from model import load_quran_data, load_vocabulary

# Load vocabulary and ayat
vocabulary, vocab_size = load_vocabulary('vocabulary.json')
ayat = load_quran_data('../Muhaffez/quran-simple-min.txt')

print(f'Vocabulary size: {vocab_size}')
print(f'Total ayat: {len(ayat)}')
print('\nGenerating clean training inputs (first 70 chars) for all ayat...')

# Generate training inputs for each ayah
with open('training_inputs_clean.txt', 'w', encoding='utf-8') as f:
    f.write('# Training inputs for all ayat (first 70 characters, no distortions)\n')
    f.write(f'# Total ayat: {len(ayat)}\n')
    f.write('# Format: Ayah Index -> Input (first 70 chars) -> Target (full ayah)\n\n')

    for idx, ayah in enumerate(ayat):
        # Take first 70 characters
        input_text = ayah[:70]

        f.write(f"Ayah Index: {idx}\n")
        f.write(f"Input: {input_text}\n")
        f.write(f"Target: {ayah}\n\n")

        if (idx + 1) % 1000 == 0:
            print(f'  Processed {idx + 1}/{len(ayat)} ayat')

print(f'\n✓ Generated clean training inputs for all {len(ayat)} ayat')
print('✓ Saved to: training_inputs_clean.txt')
