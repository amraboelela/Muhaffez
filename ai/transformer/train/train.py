import json
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
import sys
import os
import random
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))
from seq2seq_model import QuranSeq2SeqModel, load_vocabulary, load_quran_data
import time


def load_dataset_from_json(json_path):
    """Load pre-generated dataset from JSON file"""
    with open(json_path, 'r', encoding='utf-8') as f:
        dataset = json.load(f)
    return dataset


class QuranSeq2SeqFromJSONDataset(Dataset):
    """Dataset that loads from pre-generated JSON files (for skip-first variants)"""
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


class RandomSamplingDataset(Dataset):
    """Randomly samples from multiple datasets until all samples are used once per epoch"""
    def __init__(self, datasets):
        self.datasets = datasets
        # Create a list of (dataset_idx, sample_idx) tuples for all samples
        self.base_samples = []
        for dataset_idx, dataset in enumerate(datasets):
            for sample_idx in range(len(dataset)):
                self.base_samples.append((dataset_idx, sample_idx))

        # This will be reshuffled each epoch
        self.epoch_samples = None
        self.reshuffle()

    def reshuffle(self):
        """Reshuffle samples for a new epoch"""
        self.epoch_samples = self.base_samples.copy()
        random.shuffle(self.epoch_samples)

    def __len__(self):
        # Total samples across all datasets
        return len(self.base_samples)

    def __getitem__(self, idx):
        # Get the dataset and sample index from the shuffled list
        dataset_idx, sample_idx = self.epoch_samples[idx]
        return self.datasets[dataset_idx][sample_idx]


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
        # Pad inputs (will be masked by attention mask)
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


def log_print(message, log_file=None):
    """Print to console and log file"""
    print(message)
    if log_file:
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(message + '\n')


def show_sample_predictions(model, data_loader, device, idx_to_word, num_samples=3, log_file=None):
    """Show sample predictions for debugging"""
    import random
    model.eval()

    # Look up special token IDs from idx_to_word (reversed mapping)
    word_to_idx = {word: idx for idx, word in idx_to_word.items()}
    reader_token = word_to_idx['القاريء:']
    ayah_token = word_to_idx['الاية:']

    # Randomly select one batch from the data_loader
    dataset = data_loader.dataset
    batch_size = data_loader.batch_size

    # Randomly select indices
    random_indices = random.sample(range(len(dataset)), min(num_samples, len(dataset)))

    with torch.no_grad():
        for idx in random_indices:
            x, y, mask, output_tokens = dataset[idx]

            # Add batch dimension
            data = x.unsqueeze(0).to(device)
            attention_mask = torch.ones_like(data).to(device)

            logits = model(data, attention_mask=attention_mask)
            predictions = torch.argmax(logits, dim=-1)

            # Get the full input sequence
            input_seq = x.tolist()

            # Find positions of special tokens
            try:
                reader_pos = input_seq.index(reader_token)
                ayah_pos = input_seq.index(ayah_token)
            except ValueError:
                continue

            # Extract input words (between القاريء: and الاية:)
            input_words_tokens = input_seq[reader_pos+1:ayah_pos]
            input_words = [idx_to_word[token] for token in input_words_tokens]

            # Find where the mask starts
            mask_positions = torch.where(mask > 0)[0]
            if len(mask_positions) == 0:
                continue

            expected_tokens = output_tokens
            num_expected = len(expected_tokens)

            # Get predicted tokens using straight argmax (only for expected length)
            predicted_tokens = []
            for pos in mask_positions[:num_expected]:
                predicted_tokens.append(predictions[0, pos].item())

            # Convert to words
            predicted_words = [idx_to_word[token] for token in predicted_tokens]
            expected_words = [idx_to_word[token] for token in expected_tokens]

            # Count matches
            matches = sum(1 for p, e in zip(predicted_tokens, expected_tokens) if p == e)

            log_print(f'  Sample:', log_file)
            log_print(f'    القاريء: {" ".join(input_words)}', log_file)
            log_print(f'    الاية: {" ".join(expected_words)}', log_file)
            log_print(f'    Predicted: {" ".join(predicted_words)} | Match={matches}/{num_expected}', log_file)

    model.train()



def train_model(model, train_loader, combined_dataset, criterion, optimizer, scheduler, device, idx_to_word, epochs=50, log_file=None, prev_loss_init=None, checkpoint_path='../model/quran_seq2seq_model.pt'):
    """Train the seq2seq model"""
    model.train()

    best_accuracy = 0.0
    best_loss = float('inf')
    best_model_state = None
    prev_loss = prev_loss_init if prev_loss_init is not None else float('inf')

    total_start_time = time.time()

    for epoch in range(epochs):
        # Reshuffle the dataset for this epoch
        combined_dataset.reshuffle()

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

        # Save best checkpoint (based on accuracy, then loss)
        if accuracy > best_accuracy or (accuracy == best_accuracy and avg_loss < best_loss):
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
            }, checkpoint_path)

        # Early stopping if accuracy >= 97% (use rounded value to match display)
        if round(accuracy, 1) >= 97.0:
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
    # Don't specify log file - let train.sh handle output redirection
    log_file = None

    log_print('=' * 60, log_file)
    log_print('QURAN SEQ2SEQ TRANSFORMER - COMBINED 10→3 WORDS', log_file)
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

    log_print(f'✓ Training format: Random sampling from datasets (3→6 words)', log_file)
    log_print('', log_file)

    # Load existing datasets and randomly sample from all of them
    datasets = []

    # For each input word count (3 to 6), add regular and skip variants
    for input_words in range(3, 7):  # 3 to 6
        # Regular dataset: Nto6 (load from JSON)
        json_path = f'../datasets/dataset_{input_words}_to_6.json'
        if os.path.exists(json_path):
            dataset = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
            datasets.append(dataset)
            log_print(f'  Dataset {input_words}to6: {len(dataset)} samples', log_file)

        # Skip-first dataset: Nto6_1 (only for 4-6)
        if input_words >= 4:
            json_path = f'../datasets/dataset_{input_words}_to_6_1.json'
            if os.path.exists(json_path):
                dataset_skip = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
                datasets.append(dataset_skip)
                log_print(f'  Dataset {input_words}to6_1: {len(dataset_skip)} samples', log_file)

        # Skip-second dataset: Nto6_2 (only for 4-6)
        if input_words >= 4:
            json_path = f'../datasets/dataset_{input_words}_to_6_2.json'
            if os.path.exists(json_path):
                dataset_skip2 = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
                datasets.append(dataset_skip2)
                log_print(f'  Dataset {input_words}to6_2: {len(dataset_skip2)} samples', log_file)

        # Skip-third dataset: Nto6_3 (only for 4-6)
        if input_words >= 4:
            json_path = f'../datasets/dataset_{input_words}_to_6_3.json'
            if os.path.exists(json_path):
                dataset_skip3 = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
                datasets.append(dataset_skip3)
                log_print(f'  Dataset {input_words}to6_3: {len(dataset_skip3)} samples', log_file)

        # Skip-fourth dataset: Nto6_4 (only for 5-6)
        if input_words >= 5:
            json_path = f'../datasets/dataset_{input_words}_to_6_4.json'
            if os.path.exists(json_path):
                dataset_skip4 = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
                datasets.append(dataset_skip4)
                log_print(f'  Dataset {input_words}to6_4: {len(dataset_skip4)} samples', log_file)

        # Skip-fifth dataset: Nto6_5 (only for 6)
        if input_words >= 6:
            json_path = f'../datasets/dataset_{input_words}_to_6_5.json'
            if os.path.exists(json_path):
                dataset_skip5 = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
                datasets.append(dataset_skip5)
                log_print(f'  Dataset {input_words}to6_5: {len(dataset_skip5)} samples', log_file)

        # Replace-first dataset: Nto6_x1 (for 3-6)
        json_path = f'../datasets/dataset_{input_words}_to_6_x1.json'
        if os.path.exists(json_path):
            dataset_replacex1 = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
            datasets.append(dataset_replacex1)
            log_print(f'  Dataset {input_words}to6_x1: {len(dataset_replacex1)} samples', log_file)

        # Replace-second dataset: Nto6_x2 (for 4-6)
        if input_words >= 4:
            json_path = f'../datasets/dataset_{input_words}_to_6_x2.json'
            if os.path.exists(json_path):
                dataset_replacex2 = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
                datasets.append(dataset_replacex2)
                log_print(f'  Dataset {input_words}to6_x2: {len(dataset_replacex2)} samples', log_file)

        # Replace-third dataset: Nto6_x3 (for 4-6)
        if input_words >= 4:
            json_path = f'../datasets/dataset_{input_words}_to_6_x3.json'
            if os.path.exists(json_path):
                dataset_replacex3 = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
                datasets.append(dataset_replacex3)
                log_print(f'  Dataset {input_words}to6_x3: {len(dataset_replacex3)} samples', log_file)

        # Replace-fourth dataset: Nto6_x4 (for 5-6)
        if input_words >= 5:
            json_path = f'../datasets/dataset_{input_words}_to_6_x4.json'
            if os.path.exists(json_path):
                dataset_replacex4 = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
                datasets.append(dataset_replacex4)
                log_print(f'  Dataset {input_words}to6_x4: {len(dataset_replacex4)} samples', log_file)

        # Replace-fifth dataset: Nto6_x5 (only for 6)
        if input_words >= 6:
            json_path = f'../datasets/dataset_{input_words}_to_6_x5.json'
            if os.path.exists(json_path):
                dataset_replacex5 = QuranSeq2SeqFromJSONDataset(json_path, word_to_idx)
                datasets.append(dataset_replacex5)
                log_print(f'  Dataset {input_words}to6_x5: {len(dataset_replacex5)} samples', log_file)

    # Use random sampling dataset
    combined_dataset = RandomSamplingDataset(datasets)
    log_print('', log_file)
    log_print(f'✓ Random sampling dataset: {len(combined_dataset)} total samples from {len(datasets)} datasets', log_file)
    log_print('', log_file)

    train_loader = DataLoader(combined_dataset, batch_size=32, collate_fn=collate_fn, num_workers=0)

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
    best_accuracy, best_loss = train_model(model, train_loader, combined_dataset, criterion, optimizer, scheduler, device, idx_to_word, epochs=500, log_file=log_file, prev_loss_init=checkpoint_prev_loss, checkpoint_path=checkpoint_path)

    log_print('', log_file)
    log_print('=' * 60, log_file)
    log_print(f'✓ TRAINING COMPLETED!', log_file)
    log_print(f'Best checkpoint saved to: {checkpoint_path}', log_file)
    log_print(f'FINAL_ACCURACY: {best_accuracy:.1f}%', log_file)
    log_print(f'FINAL_LOSS: {best_loss:.4f}', log_file)
    log_print('=' * 60, log_file)


if __name__ == '__main__':
    main()
