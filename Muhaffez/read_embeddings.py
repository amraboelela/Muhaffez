#!/usr/bin/env python3
"""
Read and explore Quran embeddings
Created by Amr Aboelela
"""

import numpy as np
import json

# Load embeddings
embeddings = np.load('quran_embeddings.npy')
print(f"Shape: {embeddings.shape}")

# Load metadata
with open('quran_embeddings_metadata.json', 'r', encoding='utf-8') as f:
    metadata = json.load(f)

print(f"Model: {metadata['model']}")
print(f"Total embeddings: {metadata['total_embeddings']}")
print(f"Embedding dimension: {metadata['embedding_dim']}")

# Example: Get first ayah
first_embedding = embeddings[0]
first_text = metadata['lines'][0]['text']
print(f"\nFirst ayah: {first_text}")
print(f"Embedding shape: {first_embedding.shape}")

# Example: Find embedding for a specific line number
line_num = 10
for item in metadata['lines']:
    if item['line_number'] == line_num:
        idx = item['embedding_index']
        embedding = embeddings[idx]
        text = item['text']
        print(f"\nLine {line_num}: {text}")
        break

# Normalize embeddings for cosine similarity
embeddings_norm = embeddings / (np.linalg.norm(embeddings, axis=1, keepdims=True) + 1e-10)

# Verify normalization (should print ~1.0)
print(f"\nNorm of first embedding: {np.linalg.norm(embeddings_norm[0]):.6f}")

# Compute cosine similarity between two ayahs
similarity = np.dot(embeddings_norm[0], embeddings_norm[1])
print(f"\nCosine similarity between first two ayahs: {similarity:.4f}")

# Find top 5 most similar ayahs to the first ayah
similarities = embeddings_norm @ embeddings_norm[0]
top_5_indices = np.argsort(-similarities)[1:6]  # Skip index 0 (self)

print("\nTop 5 most similar ayahs to the first ayah:")
for idx in top_5_indices:
    text = metadata['lines'][idx]['text']
    sim = similarities[idx]
    print(f"  Similarity: {sim:.4f} - {text[:80]}...")
