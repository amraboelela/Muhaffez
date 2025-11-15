import json
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))
from seq2seq_model import QuranSeq2SeqModel, load_vocabulary, load_quran_data
import time


def load_dataset_from_json(json_path):
    """Load pre-generated dataset from JSON file"""
    with open(json_path, 'r', encoding='utf-8') as f:
        dataset = json.load(f)
    return dataset


def normalize_arabic(text):
    """Normalize Arabic text - remove tashkeel and normalize hamza variants"""
    # Arabic diacritics
    arabic_diacritics = set([
        '\u064B', '\u064C', '\u064D', '\u064E', '\u064F',
        '\u0650', '\u0651', '\u0652', '\u0653', '\u0654',
        '\u0655', '\u0656', '\u0657', '\u0658', '\u0670',
    ])

    text = ''.join(c for c in text if c not in arabic_diacritics)

    # Normalize hamza variants (keep ؤ and ئ as is, only normalize alif variants)
    # Note: We keep ئ (yeh with hamza) and ؤ (waw with hamza) as is
    # because they represent distinct sounds
    hamza_map = {
        'إ': 'ا',  # alif with hamza below
        'أ': 'ا',  # alif with hamza above
        'آ': 'ا',  # alif with madda
        # 'ؤ': 'و' - NOT normalized, kept as is
        # 'ئ': 'ي' - NOT normalized, kept as is
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
        self.bos_token = word_to_idx.get('<s>', 1)
        self.reader_token = word_to_idx.get('القاريء:', 3)
        self.ayah_token = word_to_idx.get('الاية:', 4)
        self.eos_token = word_to_idx.get('</s>', 2)

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

        # Get first 10 words for input
        input_words = words[:self.max_input_words]

        # Get up to 5 words for output (no padding)
        output_words = words[:min(len(words), self.max_output_words)]

        # Build sequence: <s> القاريء: [input_words] الاية: [output_words] </s>
        sequence_tokens = [self.bos_token, self.reader_token]
        sequence_tokens.extend(self.words_to_tokens(input_words))
        sequence_tokens.append(self.ayah_token)
        output_tokens = self.words_to_tokens(output_words)
        sequence_tokens.extend(output_tokens)
        sequence_tokens.append(self.eos_token)

        # Convert to tensor
        x = torch.tensor(sequence_tokens, dtype=torch.long)

        # Create target: shift by one position for next-token prediction
        # The last position predicts EOS, which we don't need to supervise
        y = torch.tensor(sequence_tokens[1:] + [self.eos_token], dtype=torch.long)

        # Create loss mask: ONLY supervise output tokens (not EOS)
        # mask[i] = 1 means we supervise predicting y[i] from x[i]
        mask = torch.zeros(len(sequence_tokens), dtype=torch.float)

        # Find position of 'الاية:' token
        ayah_pos = sequence_tokens.index(self.ayah_token)

        # Supervise from الاية: position for exactly len(output_tokens) positions
        # - Position ayah_pos (الاية:) → predicts first output word ✓
        # - Position ayah_pos+1 (first output) → predicts second output word ✓
        # - ...
        # - Position ayah_pos+len(output)-1 (last output) → predicts EOS ✓
        # Do NOT supervise position ayah_pos+len(output) (EOS) → nothing
        mask[ayah_pos:ayah_pos + len(output_tokens)] = 1.0

        return x, y, mask, output_tokens


def collate_fn(batch):
    """Custom collate function to handle variable-length sequences"""
    xs, ys, masks, outputs = zip(*batch)

    # Find max length in batch
    max_len = max(len(x) for x in xs)
    pad_token = 0  # <unk> - will be masked by attention_mask
    ignore_index = -100  # Standard ignore value for CrossEntropyLoss

    # Pad sequences
    padded_xs = []
    padded_ys = []
    padded_masks = []
    attention_masks = []

    for x, y, mask in zip(xs, ys, masks):
        pad_len = max_len - len(x)
        # Pad inputs with <unk> (will be masked)
        padded_x = torch.cat([x, torch.full((pad_len,), pad_token, dtype=torch.long)])
        # Pad targets with -100 (ignored by CrossEntropyLoss)
        padded_y = torch.cat([y, torch.full((pad_len,), ignore_index, dtype=torch.long)])
        # Loss mask (for supervising only after الاية:)
        padded_mask = torch.cat([mask, torch.zeros(pad_len, dtype=torch.float)])
        # Attention mask: 1 = real token, 0 = padding
        attention_mask = torch.cat([torch.ones(len(x), dtype=torch.long),
                                   torch.zeros(pad_len, dtype=torch.long)])

        padded_xs.append(padded_x)
        padded_ys.append(padded_y)
        padded_masks.append(padded_mask)
        attention_masks.append(attention_mask)

    return (torch.stack(padded_xs), torch.stack(padded_ys),
            torch.stack(padded_masks), torch.stack(attention_masks), outputs)


def calculate_accuracy(model, data_loader, device, idx_to_word):
    """Calculate accuracy on the dataset"""
    model.eval()
    correct_sequences = 0
    total_sequences = 0

    with torch.no_grad():
        for data, target, mask, attention_mask, expected_outputs in data_loader:
            data = data.to(device)
            target = target.to(device)
            mask = mask.to(device)
            attention_mask = attention_mask.to(device)

            # Forward pass
            logits = model(data, attention_mask=attention_mask)

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


def show_sample_predictions(model, data_loader, device, idx_to_word, num_samples=3, log_file=None):
    """Show sample predictions for debugging"""
    model.eval()
    samples_shown = 0

    reader_token = 3  # القاريء:
    ayah_token = 4    # الاية:

    with torch.no_grad():
        for data, target, mask, attention_mask, expected_outputs in data_loader:
            if samples_shown >= num_samples:
                break

            data = data.to(device)
            attention_mask = attention_mask.to(device)
            logits = model(data, attention_mask=attention_mask)
            predictions = torch.argmax(logits, dim=-1)

            for i in range(data.shape[0]):
                if samples_shown >= num_samples:
                    break

                # Find where the mask starts
                mask_positions = torch.where(mask[i] > 0)[0]
                if len(mask_positions) == 0:
                    continue

                # Get the full input sequence
                input_seq = data[i].cpu().tolist()

                # Find positions of special tokens
                try:
                    reader_pos = input_seq.index(reader_token)
                    ayah_pos = input_seq.index(ayah_token)
                except ValueError:
                    continue

                # Extract input words (between القاريء: and الاية:)
                input_words_tokens = input_seq[reader_pos+1:ayah_pos]
                input_words = [idx_to_word.get(token, '<unk>') for token in input_words_tokens]

                # Get predicted tokens using straight argmax
                predicted_tokens = []
                for pos in enumerate(mask_positions[:5]):  # Only look at first 5 positions
                    predicted_tokens.append(predictions[i, pos[1]].item())

                expected_tokens = expected_outputs[i]

                # Convert to words
                predicted_words = [idx_to_word.get(token, '<unk>') for token in predicted_tokens[:5]]
                expected_words = [idx_to_word.get(token, '<unk>') for token in expected_tokens[:5]]

                # Count matches
                matches = sum(1 for p, e in zip(predicted_tokens[:5], expected_tokens[:5]) if p == e)

                log_print(f'  Sample:', log_file)
                log_print(f'    القاريء: {" ".join(input_words)}', log_file)
                log_print(f'    الاية: {" ".join(expected_words)}', log_file)
                log_print(f'    Predicted: {" ".join(predicted_words)} | Match={matches}/5', log_file)

                samples_shown += 1

    model.train()



def train_model(model, train_loader, criterion, optimizer, scheduler, device, idx_to_word, epochs=50, log_file=None, prev_loss_init=None):
    """Train the seq2seq model"""
    model.train()

    best_accuracy = 0.0
    best_loss = float('inf')
    best_model_state = None
    prev_loss = prev_loss_init if prev_loss_init is not None else float('inf')

    total_start_time = time.time()

    for epoch in range(epochs):
        epoch_start_time = time.time()
        total_loss = 0
        total_tokens = 0

        for batch_idx, (data, target, mask, attention_mask, _) in enumerate(train_loader):
            data = data.to(device)
            target = target.to(device)
            mask = mask.to(device)
            attention_mask = attention_mask.to(device)

            # Forward pass
            logits = model(data, attention_mask=attention_mask)

            # Reshape for loss computation
            batch_size, seq_len, vocab_size = logits.shape
            logits_flat = logits.view(-1, vocab_size)
            target_flat = target.view(-1)
            mask_flat = mask.view(-1)

            # Compute loss only on masked positions
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

        # Show sample predictions
        show_sample_predictions(model, train_loader, device, idx_to_word, num_samples=1, log_file=log_file)

        # Save best checkpoint (based on highest accuracy only)
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
            }, '../model/quran_seq2seq_model.pt')

        # Early stopping if accuracy >= 100% (use rounded value to match display)
        if round(accuracy, 1) >= 100.0:
            msg = f'✓ Early stopping: accuracy reached {accuracy:.1f}%'
            log_print(msg, log_file)
            break

        # Decay LR by 10% if loss increased (minimum 1e-7)
        current_lr = optimizer.param_groups[0]['lr']
        if avg_loss > prev_loss and current_lr > 1e-7:
            new_lr = current_lr * 0.9
            for param_group in optimizer.param_groups:
                param_group['lr'] = new_lr
            log_print(f'  Loss increased! Reducing LR to {new_lr:.1e}', log_file)

        prev_loss = avg_loss

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
        d_model=128,
        n_heads=4,
        n_layers=4,
        d_ff=512,
        dropout=0.1
    )

    # Try to load existing checkpoint
    import os
    start_epoch = 0
    checkpoint_path = '../model/quran_seq2seq_model.pt'
    checkpoint_prev_loss = None

    # Backup existing model and log before training
    import shutil
    if os.path.exists(checkpoint_path):
        backup_path = '../model/quran_seq2seq_model_backup.pt'
        shutil.copy2(checkpoint_path, backup_path)
        log_print(f'✓ Model backup created: {backup_path}', log_file)
        log_print('', log_file)

        log_print('Loading existing checkpoint to continue training...', log_file)
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
        log_print(f'✓ Checkpoint loaded! Epoch: {epoch_num}, Accuracy: {accuracy_val}, Loss: {loss_val}', log_file)
        start_epoch = checkpoint.get('epoch', 0) + 1 if 'epoch' in checkpoint else 0
        checkpoint_prev_loss = checkpoint.get('loss', None)
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
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=3)

    # Train model
    log_print('Starting training for up to 500 epochs...', log_file)
    log_print(f'Initial Learning Rate: {optimizer.param_groups[0]["lr"]:.1e}', log_file)
    log_print('', log_file)
    best_accuracy, best_loss = train_model(model, train_loader, criterion, optimizer, scheduler, device, idx_to_word, epochs=500, log_file=log_file, prev_loss_init=checkpoint_prev_loss)

    log_print('', log_file)
    log_print('=' * 60, log_file)
    log_print(f'✓ TRAINING COMPLETED!', log_file)
    log_print(f'Best checkpoint saved to: ../model/quran_seq2seq_model.pt', log_file)
    log_print(f'FINAL_ACCURACY: {best_accuracy:.1f}%', log_file)
    log_print(f'FINAL_LOSS: {best_loss:.4f}', log_file)
    log_print('=' * 60, log_file)


if __name__ == '__main__':
    main()
