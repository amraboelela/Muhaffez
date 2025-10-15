import json
from train_normalized import normalize_arabic

# Load Quran text
with open('../Muhaffez/quran-simple-min.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

ayat = []
for line in lines:
    line = line.strip()
    if line and line != '-' and line != '*':
        ayat.append(line)

# Save first 10 normalized ayat to file
with open('training_inputs_normalized.txt', 'w', encoding='utf-8') as f:
    f.write('Original vs Normalized Training Inputs (first 10 ayat):\n\n')
    for i in range(min(10, len(ayat))):
        original = ayat[i]
        normalized = normalize_arabic(original)
        f.write(f'Ayah {i}:\n')
        f.write(f'  Original:   {original}\n')
        f.write(f'  Normalized: {normalized}\n\n')

print('✓ Saved normalized training inputs to training_inputs_normalized.txt')
