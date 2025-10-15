import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from model import QuranMatcherModel, load_vocabulary
import random
import re

def normalize_arabic(text):
    """Normalize Arabic text - remove tashkeel and normalize hamza"""
    # Remove tashkeel (diacritics)
    tashkeel = re.compile(r'[\u0617-\u061A\u064B-\u0652]')
    text = re.sub(tashkeel, '', text)

    # Normalize various hamza forms
    text = text.replace('إ', 'ا')
    text = text.replace('أ', 'ا')
    text = text.replace('آ', 'ا')
    text = text.replace('ؤ', 'و')
    text = text.replace('ئ', 'ي')

    return text

print("Training Quran Matcher with Label Smoothing and Higher Augmentation")

# Load vocabulary
vocabulary, vocab_size = load_vocabulary('vocabulary_normalized.json')
print(f'Vocabulary size: {vocab_size}')

# Load Quran text
ayat = []
with open('../Muhaffez/quran-simple-min.txt', 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if line and line not in ['*', '-']:
            ayat.append(line)

output_size = len(ayat)
print(f'Total ayat: {output_size}')

def add_aggressive_distortion(text, distortion_rate=0.25):
    """Add aggressive distortion by removing/substituting characters"""
    chars = list(text)

    # Remove characters
    num_to_remove = int(len(chars) * distortion_rate * 0.6)
    for _ in range(num_to_remove):
        if len(chars) > 1:
            idx = random.randint(0, len(chars) - 1)
            chars.pop(idx)

    # Substitute similar characters (10% of remaining)
    substitutions = {
        'ا': ['إ', 'أ', 'آ'],
        'ي': ['ى', 'ئ'],
        'و': ['ؤ'],
        'ه': ['ة'],
    }
    num_to_sub = int(len(chars) * distortion_rate * 0.4)
    for _ in range(num_to_sub):
        if chars:
            idx = random.randint(0, len(chars) - 1)
            char = chars[idx]
            if char in substitutions:
                chars[idx] = random.choice(substitutions[char])

    return ''.join(chars)

class AggressiveAugmentDataset(Dataset):
    def __init__(self, ayat, vocabulary, max_length=60, augment_prob=0.8):
        self.ayat = ayat
        self.vocabulary = vocabulary
        self.max_length = max_length
        self.pad_token = vocabulary.get('<PAD>', 0)
        self.unk_token = vocabulary.get('<UNK>', 1)
        self.augment_prob = augment_prob

    def __len__(self):
        return len(self.ayat)

    def tokenize(self, text):
        tokens = []
        for char in text[:self.max_length]:
            token = self.vocabulary.get(char, self.unk_token)
            tokens.append(token)

        while len(tokens) < self.max_length:
            tokens.append(self.pad_token)

        return tokens[:self.max_length]

    def __getitem__(self, idx):
        ayah = self.ayat[idx]

        # Normalize
        clean_ayah = normalize_arabic(ayah)

        # Apply augmentation with high probability
        if random.random() < self.augment_prob:
            clean_ayah = add_aggressive_distortion(clean_ayah, distortion_rate=0.25)

        tokens = self.tokenize(clean_ayah)

        return torch.tensor(tokens, dtype=torch.long), idx

# Training parameters
input_length = 60
hidden_size = 512
batch_size = 128
num_epochs = 100
learning_rate = 0.001
label_smoothing = 0.1  # Reduce overconfidence

# Create dataset and dataloader
dataset = AggressiveAugmentDataset(ayat, vocabulary, max_length=input_length, augment_prob=0.8)
dataloader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

# Create model
device = torch.device('mps' if torch.backends.mps.is_available() else 'cpu')
print(f'Using device: {device}')

model = QuranMatcherModel(
    vocab_size=vocab_size,
    input_length=input_length,
    hidden_size=hidden_size,
    output_size=output_size
).to(device)

# Loss with label smoothing
criterion = nn.CrossEntropyLoss(label_smoothing=label_smoothing)
optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)

print(f'\nModel parameters: {sum(p.numel() for p in model.parameters()):,}')
print(f'Training with:')
print(f'  - Batch size: {batch_size}')
print(f'  - Epochs: {num_epochs}')
print(f'  - Learning rate: {learning_rate}')
print(f'  - Label smoothing: {label_smoothing}')
print(f'  - Augmentation: 25% distortion, 80% probability')
print()

# Training loop
for epoch in range(num_epochs):
    model.train()
    total_loss = 0
    correct = 0
    total = 0

    for batch_idx, (inputs, targets) in enumerate(dataloader):
        inputs = inputs.to(device)
        targets = targets.to(device)

        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, targets)
        loss.backward()
        optimizer.step()

        total_loss += loss.item()
        _, predicted = torch.max(outputs, 1)
        total += targets.size(0)
        correct += (predicted == targets).sum().item()

    accuracy = 100 * correct / total
    avg_loss = total_loss / len(dataloader)

    if (epoch + 1) % 10 == 0:
        print(f'Epoch [{epoch+1}/{num_epochs}], Loss: {avg_loss:.4f}, Accuracy: {accuracy:.2f}%')

print(f'\nFinal Training Accuracy: {accuracy:.2f}%')

# Save model
save_dict = {
    'model_state_dict': model.state_dict(),
    'vocab_size': vocab_size,
    'input_length': input_length,
    'hidden_size': hidden_size,
    'output_size': output_size,
    'accuracy': accuracy,
    'label_smoothing': label_smoothing,
}

torch.save(save_dict, 'quran_matcher_label_smoothed.pth')
print('Model saved to quran_matcher_label_smoothed.pth')
