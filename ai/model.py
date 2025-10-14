import json
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader

class QuranAyahDataset(Dataset):
    def __init__(self, ayat_list, vocabulary, max_length=70):
        self.ayat = ayat_list
        self.vocabulary = vocabulary
        self.max_length = max_length

    def __len__(self):
        return len(self.ayat)

    def tokenize(self, text):
        """Convert text to token indices"""
        tokens = []
        pad_token = self.vocabulary.get('<PAD>', 0)
        unk_token = self.vocabulary.get('<UNK>', 1)

        for char in text:
            token = self.vocabulary.get(char, unk_token)
            tokens.append(token)

        # Pad or truncate to max_length
        if len(tokens) < self.max_length:
            tokens.extend([pad_token] * (self.max_length - len(tokens)))
        else:
            tokens = tokens[:self.max_length]

        return tokens

    def __getitem__(self, idx):
        ayah = self.ayat[idx]
        tokens = self.tokenize(ayah)

        # Input: tokenized ayah
        x = torch.tensor(tokens, dtype=torch.long)
        # Output: one-hot encoded ayah index
        y = torch.tensor(idx, dtype=torch.long)

        return x, y

class QuranMatcherModel(nn.Module):
    def __init__(self, vocab_size, input_length=70, hidden_size=256, output_size=6203):
        super(QuranMatcherModel, self).__init__()

        self.vocab_size = vocab_size
        self.input_length = input_length

        # Embedding layer to convert tokens to dense vectors
        self.embedding = nn.Embedding(vocab_size, 64)

        # Flatten embedded tokens
        self.flatten = nn.Flatten()

        # Hidden layers
        self.fc1 = nn.Linear(input_length * 64, hidden_size)
        self.relu1 = nn.ReLU()
        self.dropout1 = nn.Dropout(0.3)

        self.fc2 = nn.Linear(hidden_size, hidden_size)
        self.relu2 = nn.ReLU()
        self.dropout2 = nn.Dropout(0.3)

        # Output layer
        self.fc3 = nn.Linear(hidden_size, output_size)

    def forward(self, x):
        # x shape: (batch_size, input_length)
        x = self.embedding(x)  # (batch_size, input_length, 64)
        x = self.flatten(x)    # (batch_size, input_length * 64)

        x = self.fc1(x)
        x = self.relu1(x)
        x = self.dropout1(x)

        x = self.fc2(x)
        x = self.relu2(x)
        x = self.dropout2(x)

        x = self.fc3(x)

        return x  # Raw logits, softmax applied in loss function

def load_quran_data(quran_path):
    """Load Quran text and filter out empty lines and markers"""
    with open(quran_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    ayat = []
    for line in lines:
        line = line.strip()
        if line and line != '-' and line != '*':
            ayat.append(line)

    return ayat

def load_vocabulary(vocab_path):
    """Load vocabulary from JSON file"""
    with open(vocab_path, 'r', encoding='utf-8') as f:
        vocab_data = json.load(f)

    return vocab_data['char_to_token'], vocab_data['vocab_size']

if __name__ == "__main__":
    # Test the model architecture
    print("Testing QuranMatcherModel architecture...")

    # Load vocabulary
    vocabulary, vocab_size = load_vocabulary('vocabulary.json')
    print(f"Vocabulary size: {vocab_size}")

    # Load Quran data
    ayat = load_quran_data('../Muhaffez/quran-simple-min.txt')
    print(f"Total ayat: {len(ayat)}")

    # Create model
    model = QuranMatcherModel(vocab_size=vocab_size, output_size=len(ayat))
    print(f"\nModel architecture:")
    print(model)

    # Test with a sample
    dataset = QuranAyahDataset(ayat, vocabulary)
    sample_x, sample_y = dataset[0]
    print(f"\nSample input shape: {sample_x.shape}")
    print(f"Sample output label: {sample_y}")

    # Test forward pass
    sample_x = sample_x.unsqueeze(0)  # Add batch dimension
    output = model(sample_x)
    print(f"Model output shape: {output.shape}")
    print(f"Expected: (1, {len(ayat)})")
