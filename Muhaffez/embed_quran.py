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
This script requires the SILMA Arabic Embedding model to be downloaded first.
You can download it using:
    pip install huggingface-hub
    huggingface-cli download silma-ai/SILMA-Embeddding-1.5B-Arabic-v0.1

Alternative models that might work:
- aubmindlab/bert-base-arabertv02
- CAMeL-Lab/bert-base-arabic-camelbert-msa
- sentence-transformers/paraphrase-multilingual-mpnet-base-v2
"""

import sys
import torch
from transformers import AutoTokenizer, AutoModel
import numpy as np
import json
from tqdm import tqdm

# Model name for SILMA Arabic Embedding v0.1
MODEL_NAME = "silma-ai/SILMA-Embeddding-1.5B-Arabic-v0.1"

# Alternative models (uncomment if SILMA is not available)
# MODEL_NAME = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
# MODEL_NAME = "aubmindlab/bert-base-arabertv02"

def load_model():
    """Load SILMA Arabic Embedding model and tokenizer"""
    global MODEL_NAME
    print(f"Loading model: {MODEL_NAME}")
    try:
        tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, local_files_only=False)
        model = AutoModel.from_pretrained(MODEL_NAME, local_files_only=False)
    except Exception as e:
        print(f"\n⚠️  Error loading model: {e}")
        print("\nTrying alternative multilingual model...")
        MODEL_NAME = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
        print(f"Loading model: {MODEL_NAME}")
        tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
        model = AutoModel.from_pretrained(MODEL_NAME)

    # Move to GPU if available
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    model.eval()

    print(f"Model loaded on {device}")
    return tokenizer, model, device

def mean_pooling(model_output, attention_mask):
    """Apply mean pooling to get sentence embeddings"""
    token_embeddings = model_output[0]
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

def embed_text(text, tokenizer, model, device):
    """Generate embedding for a single text"""
    if not text or text.strip() == "" or text.strip() == "-":
        return None

    # Tokenize
    encoded_input = tokenizer(text, padding=True, truncation=True, return_tensors='pt', max_length=512)
    encoded_input = {k: v.to(device) for k, v in encoded_input.items()}

    # Generate embedding
    with torch.no_grad():
        model_output = model(**encoded_input)
        embeddings = mean_pooling(model_output, encoded_input['attention_mask'])
        # Normalize embeddings
        embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)

    return embeddings.cpu().numpy()[0]

def main():
    """Main function to process Quran text and generate embeddings"""
    input_file = "quran-simple-min.txt"

    # Load model first to determine output file names
    tokenizer, model, device = load_model()

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
        embedding = embed_text(text, tokenizer, model, device)

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
