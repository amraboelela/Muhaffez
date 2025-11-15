import json
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from seq2seq_model import QuranSeq2SeqModel, load_vocabulary, load_quran_data
import time
import sys


def normalize_arabic(text):
    """Normalize Arabic text - remove tashkeel and normalize hamza variants"""
    # Arabic diacritics
    arabic_diacritics = set([
        '\u064B', '\u064C', '\u064D', '\u064E', '\u064F',
        '\u0650', '\u0651', '\u0652', '\u0653', '\u0654',
        '\u0655', '\u0656', '\u0657', '\u0658', '\u0670',
    ])

    text = ''.join(c for c in text if c not in arabic_diacritics)

    # Normalize hamza variants
    hamza_map = {
        'إ': 'ا', 'أ': 'ا', 'آ': 'ا',
        'ؤ': 'و', 'ئ': 'ي'
    }

    for old, new in hamza_map.items():
        text = text.replace(old, new)

    return text


class QuranSeq2SeqDataset(Dataset):
    """
    Dataset for training seq2seq model
    Input format: القاريء: [first 10 words] الاية: [first 5 words]
    During training, we supervise only the tokens after 'الاية:'
    """
    def __init__(self, ayat_list, word_to_idx, max_input_words=10, max_output_words=5):
        self.ayat = ayat_list
        self.word_to_idx = word_to_idx
        self.max_input_words = max_input_words
        self.max_output_words = max_output_words
        self.unk_token = word_to_idx.get('<unk>', 0)
        self.reader_token = word_to_idx.get('القاريء:', 3)
        self.ayah_token = word_to_idx.get('الاية:', 4)

    def __len__(self):
        return len(self.ayat)

    def tokenize_words(self, text):
        """Tokenize Arabic text into words"""
        normalized = normalize_arabic(text)
        words = normalized.split()
        return words

    def words_to_tokens(self, words):
        """Convert words to token indices"""
        tokens = []
        for word in words:
            token = self.word_to_idx.get(word, self.unk_token)
            tokens.append(token)
        return tokens

    def __getitem__(self, idx):
        ayah = self.ayat[idx]

        # Tokenize into words
        words = self.tokenize_words(ayah)

        # Skip if ayah has fewer than max_output_words
        if len(words) < self.max_output_words:
            words = words + [''] * (self.max_output_words - len(words))

        # Get first 10 words for input
        input_words = words[:self.max_input_words]

        # Get first 5 words for output
        output_words = words[:self.max_output_words]

        # Build sequence: القاريء: [input_words] الاية: [output_words]
        sequence_tokens = [self.reader_token]
        sequence_tokens.extend(self.words_to_tokens(input_words))
        sequence_tokens.append(self.ayah_token)
        output_tokens = self.words_to_tokens(output_words)
        sequence_tokens.extend(output_tokens)

        # Convert to tensor
        x = torch.tensor(sequence_tokens, dtype=torch.long)

        # Create target: shift by one position for next-token prediction
        y = torch.tensor(sequence_tokens[1:] + [self.unk_token], dtype=torch.long)

        # Create loss mask: only compute loss for tokens after 'الاية:'
        mask = torch.zeros(len(sequence_tokens), dtype=torch.float)

        # Find position of 'الاية:' token
        ayah_pos = sequence_tokens.index(self.ayah_token)

        # Set mask to 1 for positions after 'الاية:'
        mask[ayah_pos+1:] = 1.0

        return x, y, mask, output_tokens


def collate_fn(batch):
    """Custom collate function to handle variable-length sequences"""
    xs, ys, masks, outputs = zip(*batch)

    # Find max length in batch
    max_len = max(len(x) for x in xs)

    # Pad sequences
    padded_xs = []
    padded_ys = []
    padded_masks = []

    for x, y, mask in zip(xs, ys, masks):
        pad_len = max_len - len(x)
        padded_x = torch.cat([x, torch.zeros(pad_len, dtype=torch.long)])
        padded_y = torch.cat([y, torch.zeros(pad_len, dtype=torch.long)])
        padded_mask = torch.cat([mask, torch.zeros(pad_len, dtype=torch.float)])

        padded_xs.append(padded_x)
        padded_ys.append(padded_y)
        padded_masks.append(padded_mask)

    return torch.stack(padded_xs), torch.stack(padded_ys), torch.stack(padded_masks), outputs


def calculate_accuracy(model, data_loader, device, idx_to_word):
    """Calculate accuracy on the dataset"""
    model.eval()
    correct_sequences = 0
    total_sequences = 0

    with torch.no_grad():
        for data, target, mask, expected_outputs in data_loader:
            data = data.to(device)
            target = target.to(device)
            mask = mask.to(device)

            # Forward pass
            logits = model(data)

            # Get predictions
            predictions = torch.argmax(logits, dim=-1)

            batch_size = data.shape[0]

            for i in range(batch_size):
                # Find where the mask starts (after الاية:)
                mask_positions = torch.where(mask[i] > 0)[0]
                if len(mask_positions) == 0:
                    continue

                # Get predicted tokens in the output section
                predicted_tokens = predictions[i, mask_positions].cpu().tolist()

                # Get expected tokens
                expected_tokens = expected_outputs[i]

                # Compare
                if predicted_tokens == expected_tokens:
                    correct_sequences += 1
                total_sequences += 1

    accuracy = 100 * correct_sequences / total_sequences if total_sequences > 0 else 0
    model.train()
    return accuracy


def log_print(message, log_file=None):
    """Print to console and log file"""
    print(message)
    if log_file:
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(message + '\n')


def train_model(model, train_loader, criterion, optimizer, scheduler, device, idx_to_word, epochs=50, log_file=None):
    """Train the seq2seq model"""
    model.train()

    best_accuracy = 0.0
    best_loss = float('inf')
    best_model_state = None

    total_start_time = time.time()

    for epoch in range(epochs):
        epoch_start_time = time.time()
        total_loss = 0
        total_tokens = 0

        # Zero gradients once at the start of epoch
        optimizer.zero_grad()

        for batch_idx, (data, target, mask, _) in enumerate(train_loader):
            data = data.to(device)
            target = target.to(device)
            mask = mask.to(device)

            # Forward pass
            logits = model(data)

            # Reshape for loss computation
            batch_size, seq_len, vocab_size = logits.shape
            logits_flat = logits.view(-1, vocab_size)
            target_flat = target.view(-1)
            mask_flat = mask.view(-1)

            # Compute loss only on masked positions
            loss_per_token = criterion(logits_flat, target_flat)
            loss_per_token = loss_per_token * mask_flat

            # Average over non-zero mask positions
            num_tokens = mask_flat.sum()
            loss = loss_per_token.sum() / (num_tokens + 1e-8)

            # Accumulate gradients (don't step optimizer yet)
            loss.backward()

            total_loss += loss.item() * num_tokens.item()
            total_tokens += num_tokens.item()

        # After processing all batches, clip gradients and update weights ONCE per epoch
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        optimizer.step()

        # Calculate accuracy
        accuracy = calculate_accuracy(model, train_loader, device, idx_to_word)

        epoch_time = time.time() - epoch_start_time
        avg_loss = total_loss / total_tokens
        total_elapsed = time.time() - total_start_time

        minutes = int(epoch_time // 60)
        seconds = int(epoch_time % 60)
        time_str = f'{minutes}m {seconds}s' if minutes > 0 else f'{seconds}s'

        msg = f'Epoch {epoch+1} | Loss={avg_loss:.4f} | Accuracy={accuracy:.1f}% | LR={scheduler.get_last_lr()[0]:.1e} | Time={time_str}'
        log_print(msg, log_file)

        # Save best checkpoint (based on accuracy)
        if accuracy > best_accuracy:
            best_accuracy = accuracy
            best_loss = avg_loss
            best_model_state = model.state_dict().copy()
            torch.save({
                'model': model.state_dict(),
                'optimizer': optimizer.state_dict(),
                'epoch': epoch,
                'vocab_size': model.vocab_size,
                'loss': avg_loss,
                'accuracy': accuracy,
            }, 'checkpoint_best.pt')
            log_print('  ⭐ NEW BEST!', log_file)

        # Early stopping if accuracy > 95%
        if accuracy > 95.0:
            msg = f'✓ Early stopping: accuracy reached {accuracy:.1f}%'
            log_print(msg, log_file)
            break

        log_print('', log_file)

        # Step the scheduler
        scheduler.step(avg_loss)

    total_training_time = time.time() - total_start_time
    minutes = int(total_training_time // 60)
    seconds = int(total_training_time % 60)

    log_print('', log_file)
    log_print(f'✓ Best accuracy: {best_accuracy:.1f}%', log_file)
    log_print(f'✓ Best loss: {best_loss:.4f}', log_file)
    log_print(f'✓ Total time: {minutes}m {seconds}s', log_file)
    return best_accuracy, best_loss


def main():
    log_file = 'log.txt'

    # Clear log file
    with open(log_file, 'w', encoding='utf-8') as f:
        f.write('')

    log_print('=' * 60, log_file)
    log_print('QURAN SEQ2SEQ TRANSFORMER TRAINING', log_file)
    log_print('=' * 60, log_file)
    log_print('', log_file)

    # Set device
    if torch.backends.mps.is_available():
        device = torch.device('mps')
        log_print('🚀 Using Metal GPU (Apple Silicon)', log_file)
    elif torch.cuda.is_available():
        device = torch.device('cuda')
        log_print('🚀 Using CUDA GPU', log_file)
    else:
        device = torch.device('cpu')
        log_print('Using CPU', log_file)
    log_print(f'Device: {device}', log_file)
    log_print('', log_file)

    # Load vocabulary
    word_to_idx, idx_to_word, vocab_size = load_vocabulary('../model/vocabulary.json')
    log_print(f'Vocabulary size: {vocab_size}', log_file)

    # Load Quran data
    ayat = load_quran_data('../../../Muhaffez/quran-simple-min.txt')
    log_print(f'✓ Total ayat: {len(ayat)}', log_file)
    log_print(f'✓ Training format: القاريء: [first 10 words] → الاية: [first 5 words]', log_file)
    log_print('', log_file)

    # Create dataset
    dataset = QuranSeq2SeqDataset(ayat, word_to_idx, max_input_words=10, max_output_words=5)
    train_loader = DataLoader(dataset, batch_size=32, shuffle=True, collate_fn=collate_fn, num_workers=0)

    # Create model
    model = QuranSeq2SeqModel(
        vocab_size=vocab_size,
        max_length=50,
        d_model=256,
        n_heads=8,
        n_layers=6,
        d_ff=1024,
        dropout=0.1
    )

    # Try to load existing checkpoint
    import os
    start_epoch = 0
    if os.path.exists('checkpoint_best.pt'):
        log_print('Loading existing checkpoint to continue training...', log_file)
        checkpoint = torch.load('checkpoint_best.pt', map_location=device)
        model.load_state_dict(checkpoint['model'])
        log_print(f'✓ Checkpoint loaded! Epoch: {checkpoint.get("epoch", "N/A") + 1}, Accuracy: {checkpoint.get("accuracy", "N/A"):.1f}%, Loss: {checkpoint.get("loss", "N/A"):.4f}', log_file)
        start_epoch = checkpoint.get('epoch', 0) + 1
    else:
        log_print('No existing checkpoint found, starting from scratch', log_file)
    log_print('', log_file)

    model = model.to(device)

    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    log_print(f'Total parameters: {total_params:,}', log_file)
    log_print('', log_file)

    # Loss and optimizer
    criterion = nn.CrossEntropyLoss(reduction='none')
    optimizer = optim.Adam(model.parameters(), lr=0.0001)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=3)

    # Train model
    log_print('Starting training for up to 100 epochs...', log_file)
    log_print(f'Initial Learning Rate: {optimizer.param_groups[0]["lr"]:.1e}', log_file)
    log_print('', log_file)
    best_accuracy, best_loss = train_model(model, train_loader, criterion, optimizer, scheduler, device, idx_to_word, epochs=100, log_file=log_file)

    log_print('', log_file)
    log_print('=' * 60, log_file)
    log_print(f'✓ TRAINING COMPLETED!', log_file)
    log_print(f'Best checkpoint saved to: checkpoint_best.pt', log_file)
    log_print(f'FINAL_ACCURACY: {best_accuracy:.1f}%', log_file)
    log_print(f'FINAL_LOSS: {best_loss:.4f}', log_file)
    log_print('=' * 60, log_file)


if __name__ == '__main__':
    main()
