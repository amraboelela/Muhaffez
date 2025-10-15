import json
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Dataset
from model import QuranMatcherModel, load_quran_data, load_vocabulary
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

class TruncatedQuranDataset(Dataset):
    """Dataset that uses only first N words from each ayah"""
    def __init__(self, ayat_list, vocabulary, num_words, max_length=60):
        self.ayat = [normalize_arabic(ayah) for ayah in ayat_list]
        self.vocabulary = vocabulary
        self.num_words = num_words
        self.max_length = max_length
        self.pad_token = vocabulary.get('<PAD>', 0)
        self.unk_token = vocabulary.get('<UNK>', 1)

    def __len__(self):
        return len(self.ayat)

    def get_first_n_words(self, text):
        """Get only first N words from text"""
        words = text.split()
        first_n = ' '.join(words[:self.num_words])
        return first_n

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
        ayah = self.get_first_n_words(ayah)
        clean_ayah = ayah[:self.max_length]
        tokens = self.tokenize(clean_ayah)

        x = torch.tensor(tokens, dtype=torch.long)
        y = torch.tensor(idx, dtype=torch.long)

        return x, y

def test_model(model, test_loader, device):
    """Test the model and return accuracy"""
    model.eval()
    correct = 0
    total = 0

    with torch.no_grad():
        for data, target in test_loader:
            data, target = data.to(device), target.to(device)
            output = model(data)
            _, predicted = torch.max(output.data, 1)
            total += target.size(0)
            correct += (predicted == target).sum().item()

    accuracy = 100 * correct / total
    return accuracy

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

    # Load pre-trained model
    print('\nLoading pre-trained model (trained on full sequences)...')
    checkpoint = torch.load('quran_matcher_model_normalized.pth', map_location=device)

    results = []

    # Test on different word counts
    for num_words in [4, 5, 6, 7, 8, 9, 10]:
        print(f'\n{"="*60}')
        print(f'Testing with first {num_words} words from each ayah...')
        print(f'{"="*60}')

        # Create dataset
        dataset = TruncatedQuranDataset(ayat, vocabulary, num_words=num_words, max_length=60)
        test_loader = DataLoader(dataset, batch_size=64, shuffle=False, num_workers=0)

        # Create model with same architecture
        model = QuranMatcherModel(vocab_size=vocab_size, input_length=60, hidden_size=512, output_size=len(ayat))
        model.load_state_dict(checkpoint['model_state_dict'])
        model = model.to(device)

        # Test model
        accuracy = test_model(model, test_loader, device)
        print(f'Accuracy with {num_words} words: {accuracy:.2f}%')

        results.append({
            'words': num_words,
            'accuracy': accuracy
        })

    # Print summary table
    print(f'\n{"="*60}')
    print('SUMMARY: Pre-trained model (trained on full sequences)')
    print('tested on truncated data (first N words only)')
    print(f'{"="*60}')
    print(f'{"Words":<10} {"Accuracy":<15}')
    print(f'{"-"*60}')
    for result in results:
        print(f'{result["words"]:<10} {result["accuracy"]:.2f}%')
    print(f'{"="*60}')

if __name__ == '__main__':
    main()
