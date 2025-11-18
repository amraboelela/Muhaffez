#!/usr/bin/env python3
"""
Train on a single dataset specified by command line argument
Usage: python train_dataset.py dataset_3_to_5.json
"""
import sys
import os

# Force unbuffered output
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

import json
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))
from seq2seq_model import QuranSeq2SeqModel, load_vocabulary
import time


class QuranSeq2SeqFromJSONDataset(Dataset):
    """Dataset that loads from pre-generated JSON files"""
    def __init__(self, json_path, word_to_idx):
        with open(json_path, 'r', encoding='utf-8') as f:
            self.data = json.load(f)
        self.word_to_idx = word_to_idx
        self.bos_token = word_to_idx['<s>']
        self.eos_token = word_to_idx['</s>']
        self.reader_token = word_to_idx['القاريء:']
        self.ayah_token = word_to_idx['الاية:']

    def __len__(self):
        return len(self.data)

    def words_to_tokens(self, words):
        tokens = []
        for word in words:
            token = self.word_to_idx[word]
            tokens.append(token)
        return tokens

    def __getitem__(self, idx):
        entry = self.data[idx]
        input_words = entry['input'].split()
        output_words = entry['output'].split()

        # Build sequence
        sequence_tokens = [self.bos_token, self.reader_token]
        sequence_tokens.extend(self.words_to_tokens(input_words))
        sequence_tokens.append(self.ayah_token)
        output_tokens = self.words_to_tokens(output_words)
        sequence_tokens.extend(output_tokens)
        sequence_tokens.append(self.eos_token)

        x = torch.tensor(sequence_tokens, dtype=torch.long)
        y = torch.tensor(sequence_tokens[1:] + [self.eos_token], dtype=torch.long)
        mask = torch.zeros(len(sequence_tokens), dtype=torch.float)
        ayah_pos = sequence_tokens.index(self.ayah_token)
        mask[ayah_pos:ayah_pos + len(output_tokens)] = 1.0

        return x, y, mask, output_tokens


def collate_fn(batch):
    """Custom collate function to handle variable-length sequences"""
    xs, ys, masks, outputs = zip(*batch)

    # Find max length in batch
    max_len = max(len(x) for x in xs)
    pad_token = 0  # <pad> token (will be masked by attention_mask)
    ignore_index = -100  # Standard ignore value for CrossEntropyLoss

    # Pad sequences
    padded_xs = []
    padded_ys = []
    padded_masks = []
    attention_masks = []

    for x, y, mask in zip(xs, ys, masks):
        pad_len = max_len - len(x)
        padded_x = torch.cat([x, torch.full((pad_len,), pad_token, dtype=torch.long)])
        padded_y = torch.cat([y, torch.full((pad_len,), ignore_index, dtype=torch.long)])
        padded_mask = torch.cat([mask, torch.zeros(pad_len, dtype=torch.float)])
        attention_mask = torch.cat([torch.ones(len(x), dtype=torch.long),
                                   torch.zeros(pad_len, dtype=torch.long)])

        padded_xs.append(padded_x)
        padded_ys.append(padded_y)
        padded_masks.append(padded_mask)
        attention_masks.append(attention_mask)

    return (torch.stack(padded_xs), torch.stack(padded_ys),
            torch.stack(padded_masks), torch.stack(attention_masks), outputs)


def calculate_accuracy(model, data_loader, device, idx_to_word):
    """Calculate accuracy on the dataset using autoregressive generation (SLOW but correct)"""
    model.eval()

    # Get word_to_idx from idx_to_word
    word_to_idx = {word: idx for idx, word in idx_to_word.items()}
    eos_token = word_to_idx['</s>']
    ayah_token = word_to_idx['الاية:']

    correct_sequences = 0
    total_sequences = 0

    with torch.no_grad():
        for data, target, mask, attention_mask, expected_outputs in data_loader:
            data = data.to(device)
            batch_size = data.shape[0]

            for i in range(batch_size):
                # Find position of الاية: marker in the input
                seq = data[i].cpu().tolist()
                try:
                    ayah_pos = seq.index(ayah_token)
                except ValueError:
                    continue

                # Build initial sequence up to (and including) الاية:
                initial_sequence = seq[:ayah_pos + 1]
                sequence_tokens = initial_sequence.copy()

                # Get expected tokens
                expected_tokens = expected_outputs[i]
                num_expected = len(expected_tokens)

                # Autoregressive generation
                predicted_tokens = []
                max_output_words = num_expected

                for j in range(max_output_words):
                    # Convert current sequence to tensor
                    input_tensor = torch.tensor([sequence_tokens], dtype=torch.long).to(device)
                    attention_mask_tensor = torch.ones_like(input_tensor).to(device)

                    # Get model predictions
                    logits = model(input_tensor, attention_mask=attention_mask_tensor)
                    predictions = torch.argmax(logits, dim=-1)

                    # Get prediction for the last position (next token to generate)
                    next_token = predictions[0, -1].item()

                    # Stop if we predict </s>
                    if next_token == eos_token:
                        break

                    # Append predicted token
                    predicted_tokens.append(next_token)
                    sequence_tokens.append(next_token)

                # Compare predicted tokens with expected tokens
                if predicted_tokens == expected_tokens:
                    correct_sequences += 1
                total_sequences += 1

    accuracy = 100 * correct_sequences / total_sequences if total_sequences > 0 else 0
    model.train()
    return accuracy


def calculate_fast_accuracy(model, data_loader, device, idx_to_word):
    """Calculate accuracy using parallel evaluation (FAST - teacher forcing context)"""
    model.eval()
    correct_sequences = 0
    total_sequences = 0

    with torch.no_grad():
        for data, target, mask, attention_mask, expected_outputs in data_loader:
            data = data.to(device)
            target = target.to(device)
            mask = mask.to(device)
            attention_mask = attention_mask.to(device)

            # Forward pass (parallel - sees full sequence with causal masking)
            logits = model(data, attention_mask=attention_mask)

            # Get predictions
            predictions = torch.argmax(logits, dim=-1)

            batch_size = data.shape[0]

            for i in range(batch_size):
                # Find where the mask starts (after الاية:)
                mask_positions = torch.where(mask[i] > 0)[0]
                if len(mask_positions) == 0:
                    continue

                # Get expected tokens
                expected_tokens = expected_outputs[i]
                num_expected = len(expected_tokens)

                # Get predicted tokens in the output section (only up to expected length)
                predicted_tokens = predictions[i, mask_positions[:num_expected]].cpu().tolist()

                # Compare
                if predicted_tokens == expected_tokens:
                    correct_sequences += 1
                total_sequences += 1

    accuracy = 100 * correct_sequences / total_sequences if total_sequences > 0 else 0
    model.train()
    return accuracy


def show_sample_predictions(model, data_loader, device, idx_to_word, num_samples=3):
    """Show sample predictions for debugging"""
    import random
    model.eval()

    # Look up special token IDs from idx_to_word (reversed mapping)
    word_to_idx = {word: idx for idx, word in idx_to_word.items()}
    reader_token = word_to_idx['القاريء:']
    ayah_token = word_to_idx['الاية:']

    dataset = data_loader.dataset
    random_indices = random.sample(range(len(dataset)), min(num_samples, len(dataset)))

    with torch.no_grad():
        for idx in random_indices:
            x, y, mask, output_tokens = dataset[idx]

            data = x.unsqueeze(0).to(device)
            attention_mask = torch.ones_like(data).to(device)

            logits = model(data, attention_mask=attention_mask)
            predictions = torch.argmax(logits, dim=-1)

            input_seq = x.tolist()

            try:
                reader_pos = input_seq.index(reader_token)
                ayah_pos = input_seq.index(ayah_token)
            except ValueError:
                continue

            input_words_tokens = input_seq[reader_pos+1:ayah_pos]
            input_words = [idx_to_word[token] for token in input_words_tokens]

            mask_positions = torch.where(mask > 0)[0]
            if len(mask_positions) == 0:
                continue

            expected_tokens = output_tokens
            num_expected = len(expected_tokens)

            predicted_tokens = []
            for pos in mask_positions[:num_expected]:
                predicted_tokens.append(predictions[0, pos].item())

            predicted_words = [idx_to_word[token] for token in predicted_tokens]
            expected_words = [idx_to_word[token] for token in expected_tokens]

            matches = sum(1 for p, e in zip(predicted_tokens, expected_tokens) if p == e)

            print(f'  Sample:', flush=True)
            print(f'    القاريء: {" ".join(input_words)}', flush=True)
            print(f'    الاية: {" ".join(expected_words)}', flush=True)
            print(f'    Predicted: {" ".join(predicted_words)} | Match={matches}/{num_expected}', flush=True)

    model.train()


def train_model(model, train_loader, criterion, optimizer, scheduler, device, idx_to_word, epochs=500, checkpoint_path='../model/quran_seq2seq_model.pt'):
    """Train the seq2seq model"""
    model.train()

    best_accuracy = 0.0
    best_loss = float('inf')
    vocab_size = model.vocab_size

    total_start_time = time.time()

    for epoch in range(epochs):
        epoch_start_time = time.time()
        total_loss = 0
        total_tokens = 0

        for batch_idx, (data, target, mask, attention_mask, expected_outputs) in enumerate(train_loader):
            data = data.to(device)
            target = target.to(device)
            mask = mask.to(device)
            attention_mask = attention_mask.to(device)

            # Forward pass (parallel - one pass per sample)
            logits = model(data, attention_mask=attention_mask)

            # Reshape for loss computation
            batch_size, seq_len, vocab_size = logits.shape
            logits_flat = logits.view(-1, vocab_size)
            target_flat = target.view(-1)
            mask_flat = mask.view(-1)

            # Compute loss only on masked positions (after الاية:)
            # Note: targets with -100 are automatically ignored by CrossEntropyLoss
            loss_per_token = criterion(logits_flat, target_flat)
            loss_per_token = loss_per_token * mask_flat

            # Average over non-zero mask positions
            num_tokens = mask_flat.sum()
            loss = loss_per_token.sum() / (num_tokens + 1e-8)

            # Backpropagation and optimization (per batch)
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()

            total_loss += loss.item() * num_tokens.item()
            total_tokens += num_tokens.item()

        epoch_time = time.time() - epoch_start_time
        avg_loss = total_loss / total_tokens

        minutes = int(epoch_time // 60)
        seconds = int(epoch_time % 60)
        time_str = f'{minutes}m {seconds}s' if minutes > 0 else f'{seconds}s'

        # Calculate fast accuracy every epoch (teacher forcing context)
        fast_accuracy = calculate_fast_accuracy(model, train_loader, device, idx_to_word)

        # No autoregressive accuracy during training - only at the end
        accuracy = 0.0
        print(f'Epoch {epoch+1} | Loss={avg_loss:.4f} | Fast Acc={fast_accuracy:.1f}% | LR={scheduler.get_last_lr()[0]:.1e} | Time={time_str}', flush=True)

        # Show sample predictions (removed - only show at end)

        # Save best checkpoint (based on loss)
        if avg_loss < best_loss:
            best_loss = avg_loss
            torch.save({
                'model': model.state_dict(),
                'optimizer': optimizer.state_dict(),
                'epoch': epoch,
                'vocab_size': vocab_size,
                'loss': avg_loss,
                'accuracy': 0.0,
            }, checkpoint_path)

        # Early stopping based on LR minimum (no autoregressive check during training)
        current_lr = optimizer.param_groups[0]['lr']
        if avg_loss > best_loss and current_lr <= 1e-7:
            # LR at minimum and loss still increasing - stop training
            print(f'✓ Early stopping: LR at minimum ({current_lr:.1e}) and loss not improving', flush=True)
            break

        scheduler.step(avg_loss)

    # Final autoregressive accuracy calculation (if not already done)
    if best_accuracy == 0.0:
        print('', flush=True)
        print('Calculating final autoregressive accuracy...', flush=True)
        final_accuracy = calculate_accuracy(model, train_loader, device, idx_to_word)
        print(f'✓ Final autoregressive accuracy: {final_accuracy:.1f}%', flush=True)
        best_accuracy = final_accuracy

    total_training_time = time.time() - total_start_time
    minutes = int(total_training_time // 60)
    seconds = int(total_training_time % 60)

    print('', flush=True)
    print(f'✓ Best accuracy: {best_accuracy:.1f}%', flush=True)
    print(f'✓ Best loss: {best_loss:.4f}', flush=True)
    print(f'✓ Total time: {minutes}m {seconds}s', flush=True)
    return best_accuracy, best_loss


def main():
    if len(sys.argv) < 2:
        print("Usage: python train_dataset.py <dataset_name>", flush=True)
        print("Example: python train_dataset.py dataset_3_to_5", flush=True)
        print("        python train_dataset.py dataset_10_to_5_1", flush=True)
        sys.exit(1)

    dataset_name = sys.argv[1]

    # Automatically add .json extension if not provided
    if not dataset_name.endswith('.json'):
        dataset_filename = f'{dataset_name}.json'
    else:
        dataset_filename = dataset_name

    dataset_path = f'../datasets/{dataset_filename}'

    if not os.path.exists(dataset_path):
        print(f"Error: Dataset not found: {dataset_path}", flush=True)
        sys.exit(1)

    print('=' * 60, flush=True)
    print(f'TRAINING ON SINGLE DATASET: {dataset_filename}', flush=True)
    print('=' * 60, flush=True)
    print('', flush=True)

    # Set device
    if torch.backends.mps.is_available():
        device = torch.device('mps')
        print('🚀 Using Metal GPU (Apple Silicon)', flush=True)
    elif torch.cuda.is_available():
        device = torch.device('cuda')
        print('🚀 Using CUDA GPU', flush=True)
    else:
        device = torch.device('cpu')
        print('Using CPU', flush=True)
    print(f'Device: {device}', flush=True)
    print('', flush=True)

    # Load vocabulary
    word_to_idx, idx_to_word, vocab_size = load_vocabulary('../model/vocabulary.json')
    print(f'Vocabulary size: {vocab_size}', flush=True)

    # Load dataset
    dataset = QuranSeq2SeqFromJSONDataset(dataset_path, word_to_idx)
    print(f'✓ Dataset loaded: {len(dataset)} samples', flush=True)
    print('', flush=True)

    train_loader = DataLoader(dataset, batch_size=32, collate_fn=collate_fn, num_workers=0)

    # Create model
    model = QuranSeq2SeqModel(
        vocab_size=vocab_size,
        max_length=50,
        d_model=128,
        n_heads=4,
        n_layers=4,
        d_ff=512,
        dropout=0.1
    )

    # Try to load existing checkpoint
    checkpoint_path = '../model/quran_seq2seq_model.pt'
    if os.path.exists(checkpoint_path):
        print(f'Loading existing checkpoint from {checkpoint_path}...', flush=True)
        checkpoint = torch.load(checkpoint_path, map_location=device)

        # Handle both old and new checkpoint formats
        if 'model' in checkpoint:
            model.load_state_dict(checkpoint['model'])
        elif 'model_state_dict' in checkpoint:
            model.load_state_dict(checkpoint['model_state_dict'])
        else:
            # Assume checkpoint is the state dict itself
            model.load_state_dict(checkpoint)

        epoch_num = checkpoint.get('epoch', -1) + 1 if 'epoch' in checkpoint else 'N/A'
        accuracy_val = f"{checkpoint.get('accuracy', 0):.1f}%" if 'accuracy' in checkpoint else 'N/A'
        loss_val = f"{checkpoint.get('loss', 0):.4f}" if 'loss' in checkpoint else 'N/A'
        print(f'✓ Checkpoint loaded! Epoch: {epoch_num}, Accuracy: {accuracy_val}, Loss: {loss_val}', flush=True)
    else:
        print('No existing checkpoint found, starting from scratch', flush=True)
    print('', flush=True)

    model = model.to(device)

    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    print(f'Total parameters: {total_params:,}', flush=True)
    print('', flush=True)

    # Loss and optimizer
    print('Creating optimizer and scheduler...', flush=True)
    criterion = nn.CrossEntropyLoss(reduction='none')
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=3)
    print('✓ Optimizer created', flush=True)
    print('', flush=True)

    # Train model
    print('Starting training for up to 500 epochs...', flush=True)
    print(f'Initial Learning Rate: {optimizer.param_groups[0]["lr"]:.1e}', flush=True)
    print('', flush=True)

    best_accuracy, best_loss = train_model(model, train_loader, criterion, optimizer, scheduler, device, idx_to_word, epochs=500)

    print('', flush=True)
    print('=' * 60, flush=True)
    print(f'✓ TRAINING COMPLETED!', flush=True)
    print(f'FINAL_ACCURACY: {best_accuracy:.1f}%', flush=True)
    print(f'FINAL_LOSS: {best_loss:.4f}', flush=True)
    print('=' * 60, flush=True)


if __name__ == '__main__':
    main()
