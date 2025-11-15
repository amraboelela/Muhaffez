import json
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from model import QuranMatcherModel, load_quran_data, load_vocabulary
import random
import time

def remove_tashkeel(text):
    """Remove Arabic diacritics (tashkeel)"""
    arabic_diacritics = set([
        '\u064B', '\u064C', '\u064D', '\u064E', '\u064F',
        '\u0650', '\u0651', '\u0652', '\u0653', '\u0654',
        '\u0655', '\u0656', '\u0657', '\u0658', '\u0670',
    ])
    return ''.join(c for c in text if c not in arabic_diacritics)

def normalize_arabic(text):
    """Normalize Arabic text - remove tashkeel and normalize hamza variants"""
    text = remove_tashkeel(text)
    hamza_map = {
        'إ': 'ا', 'أ': 'ا', 'آ': 'ا',
        'ؤ': 'و', 'ئ': 'ي'
    }
    for old, new in hamza_map.items():
        text = text.replace(old, new)
    return text

class OmitLastLetterQuranDataset(Dataset):
    """Dataset that omits last letter from each word for robustness"""
    def __init__(self, ayat_list, vocabulary, max_length=60, omit_prob=0.5):
        # Normalize all ayat
        self.ayat = [normalize_arabic(ayah) for ayah in ayat_list]
        self.vocabulary = vocabulary
        self.max_length = max_length
        self.pad_token = vocabulary.get('<PAD>', 0)
        self.unk_token = vocabulary.get('<UNK>', 1)
        self.omit_prob = omit_prob  # Probability of omitting last letter

    def __len__(self):
        return len(self.ayat)

    def omit_last_letters(self, text):
        """Omit last letter from each word"""
        words = text.split()
        result_words = []

        for word in words:
            if len(word) > 1:
                # Remove last letter from word
                result_words.append(word[:-1])
            else:
                # Keep single-letter words as is
                result_words.append(word)

        return ' '.join(result_words)

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

        # 50% chance: omit last letter from each word
        if random.random() < self.omit_prob:
            ayah = self.omit_last_letters(ayah)

        # Take first 60 chars
        clean_ayah = ayah[:self.max_length]

        tokens = self.tokenize(clean_ayah)

        x = torch.tensor(tokens, dtype=torch.long)
        y = torch.tensor(idx, dtype=torch.long)

        return x, y

def train_model(model, train_loader, criterion, optimizer, scheduler, device, epochs=100, vocab_size=None, output_size=None):
    """Train the model"""
    model.train()
    best_accuracy = 0.0
    best_model_state = None
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
                }, 'quran_matcher_omit_last_letter.pth')
                print(f'✓ New best model saved! Accuracy: {best_accuracy:.2f}%')

        scheduler.step(avg_loss)

    total_training_time = time.time() - total_start_time
    print(f'\n✓ Best accuracy achieved: {best_accuracy:.2f}%')
    print(f'✓ Total training time: {total_training_time:.2f}s ({total_training_time/60:.2f} minutes)')
    return best_accuracy

def main():
    # Set device
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

    # Load Quran data
    ayat = load_quran_data('../Muhaffez/quran-simple-min.txt')
    print(f'Total ayat: {len(ayat)}')

    # Create dataset with last letter omission (50% probability)
    dataset = OmitLastLetterQuranDataset(ayat, vocabulary, max_length=60, omit_prob=0.5)
    train_loader = DataLoader(dataset, batch_size=64, shuffle=True, num_workers=0)

    # Create model
    model = QuranMatcherModel(vocab_size=vocab_size, input_length=60, hidden_size=512, output_size=len(ayat))

    # Load existing model if available
    import os
    if os.path.exists('quran_matcher_model_normalized.pth'):
        print('Loading existing normalized model weights to continue training...')
        checkpoint = torch.load('quran_matcher_model_normalized.pth', map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])
        print(f'Model loaded successfully! Previous best accuracy: {checkpoint.get("accuracy", "N/A")}%')
    else:
        print('No existing model found, starting from scratch')

    model = model.to(device)

    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.0005)

    # Learning rate scheduler
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=5)

    # Train model
    print('\nTraining with LAST LETTER OMISSION augmentation (50% probability)...')
    print('Removing last letter from each word for robustness\n')
    best_acc = train_model(model, train_loader, criterion, optimizer, scheduler, device, epochs=100, vocab_size=vocab_size, output_size=len(ayat))

    print(f'\n✓ Training complete! Best model saved to quran_matcher_omit_last_letter.pth with accuracy: {best_acc:.2f}%')

if __name__ == '__main__':
    main()
