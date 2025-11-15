from train_normalized import normalize_arabic

# Load Quran text
with open('../Muhaffez/quran-simple-min.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

ayat = []
for line in lines:
    line = line.strip()
    if line and line != '-' and line != '*':
        ayat.append(line)

# Calculate average length reduction
total_original = 0
total_normalized = 0
count = 0

for ayah in ayat:
    normalized = normalize_arabic(ayah)
    total_original += len(ayah)
    total_normalized += len(normalized)
    count += 1

avg_original = total_original / count
avg_normalized = total_normalized / count
reduction_percent = ((avg_original - avg_normalized) / avg_original) * 100

print(f'Average original length: {avg_original:.2f} chars')
print(f'Average normalized length: {avg_normalized:.2f} chars')
print(f'Reduction: {reduction_percent:.1f}%')
print(f'')
print(f'Recommendation:')
if reduction_percent > 30:
    recommended = int(70 * (1 - reduction_percent/100))
    print(f'  With {reduction_percent:.1f}% reduction, consider reducing from 70 to {recommended} chars')
else:
    print(f'  With only {reduction_percent:.1f}% reduction, keep 70 chars for consistency')
