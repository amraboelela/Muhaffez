#!/usr/bin/env python3
"""
Train on a single ayah to verify the model can learn - CORRECTED VERSION
"""
import torch
import torch.nn as nn
import torch.optim as optim
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))
from seq2seq_model import QuranSeq2SeqModel, load_vocabulary, load_quran_data
from train import normalize_arabic

def main():
    device = torch.device('mps' if torch.backends.mps.is_available() else 'cpu')
    print(f'Device: {device}\n')

    word_to_idx, idx_to_word, vocab_size = load_vocabulary('../model/vocabulary.json')
    ayat = load_quran_data('../../../Muhaffez/quran-simple-min.txt')
    
    # Use a longer ayah
    sample_ayah = ayat[100]
    print(f'Training sample: {sample_ayah}')

    normalized = normalize_arabic(sample_ayah)
    words = normalized.split()
    print(f'Words ({len(words)}): {words[:10]}...\n')

    input_words = words[:min(10, len(words))]
    output_words = words[:min(5, len(words))]

    print(f'Input: {" ".join(input_words)}')
    print(f'Output: {" ".join(output_words)}\n')

    # Special tokens
    bos = word_to_idx.get('<s>', 1)
    eos = word_to_idx.get('</s>', 2)
    reader = word_to_idx.get('القاريء:', 3)
    ayah = word_to_idx.get('الاية:', 4)
    unk = word_to_idx.get('<unk>', 0)

    # Build sequence
    seq = [bos, reader]
    input_tokens = [word_to_idx.get(w, unk) for w in input_words]
    output_tokens = [word_to_idx.get(w, unk) for w in output_words]
    seq.extend(input_tokens)
    seq.append(ayah)
    seq.extend(output_tokens)
    seq.append(eos)

    print(f'Sequence: {[idx_to_word.get(t, "?") for t in seq]}\n')

    x = torch.tensor([seq], dtype=torch.long, device=device)
    y = torch.tensor([seq[1:] + [eos]], dtype=torch.long, device=device)
    
    # CORRECT MASK: supervise ONLY the output tokens (not EOS)
    mask = torch.zeros((1, len(seq)), dtype=torch.float, device=device)
    ayah_pos = seq.index(ayah)
    mask[0, ayah_pos:ayah_pos + len(output_tokens)] = 1.0

    print(f'Mask supervision ({int(mask.sum())} positions):')
    for i in range(len(seq)):
        if mask[0, i] > 0:
            target = y[0, i].item()
            print(f'  Pos {i} ({idx_to_word.get(seq[i], "?")}) → {idx_to_word.get(target, "?")}')
    print()

    # Create model
    model = QuranSeq2SeqModel(vocab_size=vocab_size, max_length=50, d_model=256,
                              n_heads=8, n_layers=6, d_ff=1024, dropout=0.0).to(device)
    
    criterion = nn.CrossEntropyLoss(reduction='none')
    optimizer = optim.Adam(model.parameters(), lr=0.001)

    print('='*60)
    print('TRAINING - 500 ITERATIONS')
    print('='*60 + '\n')

    model.train()
    for it in range(500):
        optimizer.zero_grad()
        logits = model(x)
        
        loss_per_token = criterion(logits.view(-1, vocab_size), y.view(-1))
        loss_per_token = loss_per_token.view(1, -1) * mask
        loss = loss_per_token.sum() / (mask.sum() + 1e-8)
        
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        optimizer.step()

        if (it + 1) % 10 == 0 or it == 0:
            with torch.no_grad():
                preds = torch.argmax(logits[0], dim=-1).cpu().tolist()
                mask_pos = torch.where(mask[0] > 0)[0].cpu().tolist()
                pred_tokens = [preds[p] for p in mask_pos]
                matches = sum(1 for p, e in zip(pred_tokens, output_tokens) if p == e)
                acc = 100 * matches / len(output_tokens)
                pred_words = [idx_to_word.get(t, '?') for t in pred_tokens]
                print(f'Iter {it+1:3d} | Loss={loss.item():.4f} | Acc={acc:3.0f}% | {" ".join(pred_words)}')
        
        if it > 50 and acc == 100 and loss.item() < 0.01:
            print(f'\n✅ CONVERGED at iteration {it+1}\!')
            break

    print(f'\n{"="*60}')
    print(f'Final: Loss={loss.item():.4f} Acc={acc:.0f}%')
    print('✅ SUCCESS\!' if acc == 100 else '❌ FAILED')
    print('='*60)

if __name__ == '__main__':
    main()
