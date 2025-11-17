#!/usr/bin/env python3
"""
Add <pad> token at the beginning of vocabulary
This will shift all existing token indices by 1
"""
import json
import os

# Path to vocabulary
vocab_path = '../model/vocabulary.json'

# Read current vocabulary
print(f"Reading vocabulary from {vocab_path}...")
with open(vocab_path, 'r', encoding='utf-8') as f:
    vocab = json.load(f)

print(f"Current vocabulary size: {len(vocab)}")
print(f"First 10 tokens: {vocab[:10]}")

# Insert <pad> at the beginning
vocab.insert(0, "<pad>")

print(f"\nNew vocabulary size: {len(vocab)}")
print(f"First 10 tokens: {vocab[:10]}")

# Save updated vocabulary
with open(vocab_path, 'w', encoding='utf-8') as f:
    json.dump(vocab, f, ensure_ascii=False, indent=2)

print(f"\n✓ Updated vocabulary saved to {vocab_path}")
print("\nToken index changes:")
print("  <pad>: new at index 0")
print("  <s>: 0 → 1")
print("  </s>: 1 → 2")
print("  القاريء:: 2 → 3")
print("  الاية:: 3 → 4")
