import json
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from model import QuranMatcherModel, load_quran_data, load_vocabulary
import random
import time
import unicodedata

def remove_tashkeel(text):
    """Remove Arabic diacritics (tashkeel)"""
    # Arabic diacritics Unicode range
    arabic_diacritics = set([
        '\u064B',  # Fathatan
        '\u064C',  # Dammatan
        '\u064D',  # Kasratan
        '\u064E',  # Fatha
        '\u064F',  # Damma
        '\u0650',  # Kasra
        '\u0651',  # Shadda
        '\u0652',  # Sukun
        '\u0653',  # Maddah
        '\u0654',  # Hamza above
        '\u0655',  # Hamza below
        '\u0656',  # Subscript alef
        '\u0657',  # Inverted damma
        '\u0658',  # Mark noon ghunna
        '\u0670',  # Superscript alef
    ])

    return ''.join(c for c in text if c not in arabic_diacritics)

def normalize_arabic(text):
    """Normalize Arabic text - remove tashkeel and normalize hamza variants"""
    # Remove tashkeel
    text = remove_tashkeel(text)

    # Normalize hamza variants
    hamza_map = {
        'إ': 'ا', 'أ': 'ا', 'آ': 'ا',
        'ؤ': 'و', 'ئ': 'ي'
    }

    for old, new in hamza_map.items():
        text = text.replace(old, new)

    return text

def add_noise_to_text(text, noise_level=0.1):
    """Add noise to text by randomly removing characters"""
    if random.random() > 0.3:
        # Remove some characters
        chars = list(text)
        num_to_remove = int(len(chars) * noise_level)
        for _ in range(num_to_remove):
            if len(chars) > 1:
                idx = random.randint(0, len(chars) - 1)
                chars.pop(idx)
        return ''.join(chars)
    else:
        # Return without distortion (30% of the time)
        return text

class NormalizedOffsetQuranDataset(Dataset):
    """Dataset with normalized text, random offsets AND distortions"""
    def __init__(self, ayat_list, vocabulary, max_length=60):
        # Normalize all ayat
        self.ayat = [normalize_arabic(ayah) for ayah in ayat_list]
        self.vocabulary = vocabulary
        self.max_length = max_length
        self.pad_token = vocabulary.get('<PAD>', 0)
        self.unk_token = vocabulary.get('<UNK>', 1)

    def __len__(self):
        return len(self.ayat)

    def tokenize(self, text):
        """Convert text to token indices"""
        tokens = []
        for char in text:
            token = self.vocabulary.get(char, self.unk_token)
            tokens.append(token)

        # Pad or truncate to max_length
        if len(tokens) < self.max_length:
            tokens.extend([self.pad_token] * (self.max_length - len(tokens)))
        else:
            tokens = tokens[:self.max_length]

        return tokens

    def __getitem__(self, idx):
        ayah = self.ayat[idx]

        # 50% chance to use random offset (max 10 chars)
        if random.random() < 0.5 and len(ayah) > self.max_length:
            # Random offset up to 10 chars
            max_offset = min(len(ayah) - self.max_length, 10)
            if max_offset > 0:
                offset = random.randint(0, max_offset)
                clean_ayah = ayah[offset:offset + self.max_length]
            else:
                clean_ayah = ayah[:self.max_length]
        else:
            # Start from beginning
            clean_ayah = ayah[:self.max_length]

        # Apply random distortion
        distorted_ayah = add_noise_to_text(clean_ayah, noise_level=0.1)

        tokens = self.tokenize(distorted_ayah)

        x = torch.tensor(tokens, dtype=torch.long)
        y = torch.tensor(idx, dtype=torch.long)

        return x, y

def train_model(model, train_loader, criterion, optimizer, scheduler, device, epochs=10, vocab_size=None, output_size=None):
    """Train the model"""
    model.train()

    # Track best model
    best_accuracy = 0.0
    best_model_state = None

    # Track total training time
    total_start_time = time.time()

    for epoch in range(epochs):
        epoch_start_time = time.time()
        total_loss = 0
        correct = 0
        total = 0

        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to(device), target.to(device)

            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)

            loss.backward()
            optimizer.step()

            total_loss += loss.item()

            # Calculate accuracy
            _, predicted = torch.max(output.data, 1)
            total += target.size(0)
            correct += (predicted == target).sum().item()

            if batch_idx % 100 == 0:
                print(f'Epoch: {epoch+1}/{epochs}, Batch: {batch_idx}/{len(train_loader)}, '
                      f'Loss: {loss.item():.4f}, Acc: {100*correct/total:.2f}%')

        epoch_time = time.time() - epoch_start_time
        avg_loss = total_loss / len(train_loader)
        accuracy = 100 * correct / total
        total_elapsed = time.time() - total_start_time
        print(f'\nEpoch {epoch+1} Summary: Avg Loss: {avg_loss:.4f}, Accuracy: {accuracy:.2f}%, LR: {scheduler.get_last_lr()[0]:.6f}')
        print(f'Epoch Time: {epoch_time:.2f}s, Total Time: {total_elapsed:.2f}s\n')

        # Save best model
        if accuracy > best_accuracy:
            best_accuracy = accuracy
            best_model_state = model.state_dict().copy()
            if vocab_size and output_size:
                torch.save({
                    'model_state_dict': best_model_state,
                    'vocab_size': vocab_size,
                    'output_size': output_size,
                    'accuracy': best_accuracy,
                }, 'quran_matcher_model_normalized.pth')
                print(f'✓ New best model saved! Accuracy: {best_accuracy:.2f}%')

        # Step the scheduler
        scheduler.step(avg_loss)

    total_training_time = time.time() - total_start_time
    print(f'\n✓ Best accuracy achieved: {best_accuracy:.2f}%')
    print(f'✓ Total training time: {total_training_time:.2f}s ({total_training_time/60:.2f} minutes)')
    return best_accuracy

def main():
    # Set device - prefer MPS (Apple Silicon GPU) > CUDA (NVIDIA) > CPU
    if torch.backends.mps.is_available():
        device = torch.device('mps')
    elif torch.cuda.is_available():
        device = torch.device('cuda')
    else:
        device = torch.device('cpu')
    print(f'Using device: {device}')

    # Load vocabulary
    vocabulary, vocab_size = load_vocabulary('vocabulary_normalized.json')
    print(f'Vocabulary size: {vocab_size}')

    # Load Quran data (will be normalized in dataset)
    ayat = load_quran_data('../Muhaffez/quran-simple-min.txt')
    print(f'Total ayat: {len(ayat)}')

    # Create dataset with normalized text, offset + distortion augmentation
    dataset = NormalizedOffsetQuranDataset(ayat, vocabulary, max_length=60)
    # Shuffle for better training
    train_loader = DataLoader(dataset, batch_size=64, shuffle=True, num_workers=0)

    # Create model with 60 input length and 512 hidden size
    model = QuranMatcherModel(vocab_size=vocab_size, input_length=60, hidden_size=512, output_size=len(ayat))

    # Try to load existing model weights to continue training
    import os
    if os.path.exists('quran_matcher_model_normalized.pth'):
        print('Loading existing normalized model weights to continue training...')
        checkpoint = torch.load('quran_matcher_model_normalized.pth', map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])
        print(f'Model loaded successfully! Previous best accuracy: {checkpoint.get("accuracy", "N/A")}%')
    elif os.path.exists('quran_matcher_model_34vocab.pth'):
        print('Loading converted 34-vocab model weights as starting point...')
        checkpoint = torch.load('quran_matcher_model_34vocab.pth', map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])
        print('Model weights loaded successfully! (Converted from 47-vocab model)')
    else:
        print('No existing model found, starting from scratch')

    model = model.to(device)

    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.0005)

    # Learning rate scheduler - reduce LR when loss plateaus
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=5)

    # Train model
    print('\nTraining with NORMALIZED text + offset + distortion augmentation...\n')
    best_acc = train_model(model, train_loader, criterion, optimizer, scheduler, device, epochs=100, vocab_size=vocab_size, output_size=len(ayat))

    print(f'\n✓ Training complete! Best model saved to quran_matcher_model_normalized.pth with accuracy: {best_acc:.2f}%')

if __name__ == '__main__':
    main()
