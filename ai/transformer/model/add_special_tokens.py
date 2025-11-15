#!/usr/bin/env python3
import json

# Read the original vocabulary
with open('/Users/amraboelela/develop/android/AndroidArabicWhisper/muhaffez-whisper/models/vocabulary.json', 'r', encoding='utf-8') as f:
    vocab = json.load(f)

# Insert 'القاريء:' and 'الاية:' after '</s>' (index 3)
# Original: ["<unk>", "<s>", "</s>", "من", ...]
# New:      ["<unk>", "<s>", "</s>", "القاريء:", "الاية:", "من", ...]
vocab.insert(3, "القاريء:")
vocab.insert(4, "الاية:")

print(f"Total vocabulary size: {len(vocab)}")
print(f"First 10 tokens: {vocab[:10]}")

# Save to Muhaffez app directory
output_path1 = '/Users/amraboelela/develop/swift/Muhaffez/Muhaffez/vocabulary.json'
with open(output_path1, 'w', encoding='utf-8') as f:
    json.dump(vocab, f, ensure_ascii=False, indent=2)
print(f"Modified vocabulary saved to {output_path1}")

# Save to transformer directory
output_path2 = '/Users/amraboelela/develop/swift/Muhaffez/ai/transformer/vocabulary.json'
with open(output_path2, 'w', encoding='utf-8') as f:
    json.dump(vocab, f, ensure_ascii=False, indent=2)
print(f"Modified vocabulary saved to {output_path2}")
