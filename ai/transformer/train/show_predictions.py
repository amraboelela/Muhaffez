#!/usr/bin/env python3
"""
Show sample predictions from the trained model
"""

import torch
import sys
from seq2seq_model import QuranSeq2SeqModel, load_vocabulary, load_quran_data
from train import QuranSeq2SeqDataset, normalize_arabic

def show_predictions(num_samples=10):
    # Set device
    if torch.backends.mps.is_available():
        device = torch.device('mps')
    elif torch.cuda.is_available():
        device = torch.device('cuda')
    else:
        device = torch.device('cpu')

    print(f'Using device: {device}\n')

    # Load vocabulary
    word_to_idx, idx_to_word, vocab_size = load_vocabulary('../model/vocabulary.json')

    # Load Quran data
    ayat = load_quran_data('../../../Muhaffez/quran-simple-min.txt')

    # Create dataset
    dataset = QuranSeq2SeqDataset(ayat, word_to_idx, max_input_words=10, max_output_words=5)

    # Load model
    model = QuranSeq2SeqModel(
        vocab_size=vocab_size,
        max_length=50,
        d_model=256,
        n_heads=8,
        n_layers=6,
        d_ff=1024,
        dropout=0.1
    )

    # Load checkpoint
    checkpoint = torch.load('../model/quran_seq2seq_model.pt', map_location=device)
    if 'model' in checkpoint:
        model.load_state_dict(checkpoint['model'])
    elif 'model_state_dict' in checkpoint:
        model.load_state_dict(checkpoint['model_state_dict'])
    else:
        model.load_state_dict(checkpoint)

    model = model.to(device)
    model.eval()

    print('='*80)
    print(f'SAMPLE PREDICTIONS (showing first {num_samples} ayat)')
    print('='*80)
    print()

    with torch.no_grad():
        for i in range(min(num_samples, len(dataset))):
            x, y, mask, expected_tokens = dataset[i]
            x = x.unsqueeze(0).to(device)  # Add batch dimension

            # Forward pass
            logits = model(x)
            predictions = torch.argmax(logits, dim=-1)

            # Find where the mask starts (after الاية:)
            mask_positions = torch.where(mask > 0)[0]

            # Get predicted tokens in the output section
            predicted_tokens = predictions[0, mask_positions].cpu().tolist()

            # Convert tokens to words
            predicted_words = [idx_to_word.get(token, '<unk>') for token in predicted_tokens]
            expected_words = [idx_to_word.get(token, '<unk>') for token in expected_tokens]

            # Get the original ayah text
            ayah_text = ayat[i]
            normalized = normalize_arabic(ayah_text)
            all_words = normalized.split()[:10]  # First 10 words

            # Count matches
            matches = sum(1 for p, e in zip(predicted_tokens, expected_tokens) if p == e)

            print(f'Ayah {i+1}:')
            print(f'  Input (القاريء): {" ".join(all_words)}')
            print(f'  Expected (الاية): {" ".join(expected_words)}')
            print(f'  Predicted:        {" ".join(predicted_words)}')
            print(f'  Match: {matches}/{len(expected_tokens)} words correct')

            # Show which words match/differ
            status = []
            for p, e in zip(predicted_words, expected_words):
                if p == e:
                    status.append('✓')
                else:
                    status.append('✗')
            print(f'  Status: {" ".join(status)}')
            print()

if __name__ == '__main__':
    show_predictions(10)
