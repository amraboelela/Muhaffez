import json
import random
from model import load_quran_data, load_vocabulary

def add_noise_to_text(text, noise_level=0.1):
    """Add noise to text by randomly removing or changing characters"""
    if random.random() > 0.5:
        # Remove some characters
        chars = list(text)
        num_to_remove = int(len(chars) * noise_level)
        for _ in range(num_to_remove):
            if len(chars) > 1:
                idx = random.randint(0, len(chars) - 1)
                chars.pop(idx)
        return ''.join(chars)
    else:
        # Return partial text
        split_point = int(len(text) * (1 - noise_level))
        return text[:split_point]

# Load vocabulary and ayat
vocabulary, vocab_size = load_vocabulary('vocabulary.json')
ayat = load_quran_data('../Muhaffez/quran-simple-min.txt')

print(f'Vocabulary size: {vocab_size}')
print(f'Total ayat: {len(ayat)}')
print('\nGenerating training inputs for all ayat...')

# Generate training inputs for each ayah
with open('training_inputs_all.txt', 'w', encoding='utf-8') as f:
    f.write('# Training inputs for all ayat (with noise)\n')
    f.write(f'# Total ayat: {len(ayat)}\n')
    f.write('# Format: Ayah Index -> Input (distorted) -> Target (original)\n\n')

    for idx, ayah in enumerate(ayat):
        # Generate 3 noisy versions of each ayah
        for version in range(3):
            noisy_ayah = add_noise_to_text(ayah, noise_level=0.1)

            f.write(f"Ayah Index: {idx}\n")
            f.write(f"Version: {version + 1}\n")
            f.write(f"Input: {noisy_ayah}\n")
            f.write(f"Target: {ayah}\n\n")

        if (idx + 1) % 1000 == 0:
            print(f'  Processed {idx + 1}/{len(ayat)} ayat')

print(f'\n✓ Generated training inputs for all {len(ayat)} ayat (3 versions each)')
print(f'✓ Total training samples: {len(ayat) * 3}')
print('✓ Saved to: training_inputs_all.txt')
