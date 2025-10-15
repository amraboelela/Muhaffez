import json
from train_normalized import normalize_arabic

# Load Quran text
with open('../Muhaffez/quran-simple-min.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Normalize all lines
normalized_lines = []
for line in lines:
    line = line.strip()
    if line and line != '-' and line != '*':
        normalized_lines.append(normalize_arabic(line))

# Get all unique characters
all_chars = set()
for line in normalized_lines:
    for char in line:
        all_chars.add(char)

# Sort characters
sorted_chars = sorted(all_chars)

print(f"Total unique characters in normalized Quran: {len(sorted_chars)}")
print(f"Characters: {sorted_chars}")

# Create vocabulary with special tokens
char_to_token = {
    '<PAD>': 0,
    '<UNK>': 1,
}

# Add all unique characters
for idx, char in enumerate(sorted_chars, start=2):
    char_to_token[char] = idx

vocab_size = len(char_to_token)

# Create vocabulary dictionary
vocabulary = {
    'char_to_token': char_to_token,
    'vocab_size': vocab_size
}

# Save to JSON
with open('vocabulary_normalized.json', 'w', encoding='utf-8') as f:
    json.dump(vocabulary, f, ensure_ascii=False, indent=2)

print(f"\n✓ Vocabulary saved to vocabulary_normalized.json")
print(f"  Vocab size: {vocab_size} (down from 47)")
print(f"  Special tokens: <PAD>, <UNK>")
print(f"  Character tokens: {len(sorted_chars)}")

# Print the vocabulary
print(f"\nVocabulary:")
for char, token in sorted(char_to_token.items(), key=lambda x: x[1]):
    if char in ['<PAD>', '<UNK>']:
        print(f"  {token}: {char}")
    else:
        print(f"  {token}: '{char}'")
