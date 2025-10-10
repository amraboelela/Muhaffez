#!/usr/bin/env python3
"""
Embed Quran simple text file line by line using SILMA Arabic Embedding v0.1
Created by Amr Aboelela

Quran Text Source:
------------------
This script processes the Tanzil Quran Text (Simple Minimal, Version 1.1)
Copyright (C) 2007-2025 Tanzil Project
License: Creative Commons Attribution 3.0
Website: http://tanzil.net

The Tanzil Quran text is carefully produced, highly verified and continuously
monitored by a group of specialists at Tanzil Project. The text is used under
Creative Commons Attribution 3.0 license with proper attribution maintained.

Model Requirements:
-------------------
This script uses the all-MiniLM-L6-v2 model from sentence-transformers.
Install requirements:
    pip install sentence-transformers

Alternative models that might work:
- silma-ai/SILMA-Embeddding-1.5B-Arabic-v0.1 (Arabic-specific, larger)
- aubmindlab/bert-base-arabertv02 (Arabic-specific)
- sentence-transformers/paraphrase-multilingual-mpnet-base-v2 (larger multilingual)
"""

import sys
import torch
from sentence_transformers import SentenceTransformer
import numpy as np
import json
from tqdm import tqdm

# Model name for Arabic embedding model
MODEL_NAME = "SILMA-Lab/arabic-embedding-base"

# Alternative models (uncomment to use)
# MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
# MODEL_NAME = "CAMeL-Lab/bert-base-arabic-camelbert-mix-sentiment"
# MODEL_NAME = "silma-ai/SILMA-Embeddding-1.5B-Arabic-v0.1"
# MODEL_NAME = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
# MODEL_NAME = "aubmindlab/bert-base-arabertv02"

def load_model():
    """Load sentence-transformers model"""
    global MODEL_NAME
    print(f"Loading model: {MODEL_NAME}")
    try:
        model = SentenceTransformer(MODEL_NAME)
    except Exception as e:
        print(f"\n⚠️  Error loading model: {e}")
        print("\nTrying alternative multilingual model...")
        MODEL_NAME = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
        print(f"Loading model: {MODEL_NAME}")
        model = SentenceTransformer(MODEL_NAME)

    # Check device
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Model loaded on {device}")
    return model

def embed_text(text, model):
    """Generate embedding for a single text"""
    if not text or text.strip() == "" or text.strip() == "-" or text.strip() == "*":
        return None

    # Generate embedding using sentence-transformers
    embedding = model.encode(text, convert_to_numpy=True, normalize_embeddings=True)
    return embedding

def main():
    """Main function to process Quran text and generate embeddings"""
    input_file = "quran-simple-min.txt"

    # Load model first to determine output file names
    model = load_model()

    # Create output filenames based on actual model used
    model_safe_name = MODEL_NAME.replace("/", "_").replace("-", "_")
    output_file = f"quran_embeddings_{model_safe_name}.npy"
    output_json = f"quran_embeddings_{model_safe_name}_metadata.json"

    # Read input file
    print(f"\nReading input file: {input_file}")
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    print(f"Total lines: {len(lines)}")

    # Process each line
    embeddings = []
    metadata = []

    for idx, line in enumerate(tqdm(lines, desc="Generating embeddings")):
        text = line.strip()
        embedding = embed_text(text, model)

        if embedding is not None:
            embeddings.append(embedding)
            metadata.append({
                "line_number": idx + 1,
                "text": text,
                "embedding_index": len(embeddings) - 1
            })

    # Convert to numpy array and save
    embeddings_array = np.array(embeddings, dtype=np.float32)
    print(f"\nSaving embeddings to {output_file}")
    print(f"Shape: {embeddings_array.shape}")
    np.save(output_file, embeddings_array)

    # Save metadata
    print(f"Saving metadata to {output_json}")
    with open(output_json, 'w', encoding='utf-8') as f:
        json.dump({
            "model": MODEL_NAME,
            "total_embeddings": len(embeddings),
            "embedding_dim": embeddings_array.shape[1],
            "lines": metadata
        }, f, ensure_ascii=False, indent=2)

    print(f"\nCompleted!")
    print(f"Model used: {MODEL_NAME}")
    print(f"Generated {len(embeddings)} embeddings")
    print(f"Embedding dimension: {embeddings_array.shape[1]}")

if __name__ == "__main__":
    main()
