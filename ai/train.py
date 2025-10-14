import json
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from model import QuranMatcherModel, QuranAyahDataset, load_quran_data, load_vocabulary
import random

def add_noise_to_text(text, noise_level=0.2):
    """Add noise to text by randomly removing or changing characters"""
    if random.random() > 0.5:
        # Remove some characters
        chars = list(text)
        num_to_remove = int(len(chars) * noise_level)
        for _ in range(num_to_remove):
            if len(chars) > 1:
                idx = random.randint(0, len(chars) - 1)
                chars.pop(idx)
        return ''.join(chars)
    else:
        # Return partial text
        split_point = int(len(text) * (1 - noise_level))
        return text[:split_point]

class NoisyQuranDataset(QuranAyahDataset):
    """Dataset that adds noise to ayat to simulate mistakes"""
    def __init__(self, ayat_list, vocabulary, max_length=100, noise_level=0.2):
        super().__init__(ayat_list, vocabulary, max_length)
        self.noise_level = noise_level
    
    def __getitem__(self, idx):
        ayah = self.ayat[idx]
        
        # Add noise to create training input
        noisy_ayah = add_noise_to_text(ayah, self.noise_level)
        tokens = self.tokenize(noisy_ayah)
        
        x = torch.tensor(tokens, dtype=torch.long)
        y = torch.tensor(idx, dtype=torch.long)
        
        return x, y

def train_model(model, train_loader, criterion, optimizer, device, epochs=10):
    """Train the model"""
    model.train()
    
    for epoch in range(epochs):
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
        
        avg_loss = total_loss / len(train_loader)
        accuracy = 100 * correct / total
        print(f'\nEpoch {epoch+1} Summary: Avg Loss: {avg_loss:.4f}, Accuracy: {accuracy:.2f}%\n')

def main():
    # Set device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f'Using device: {device}')
    
    # Load vocabulary
    vocabulary, vocab_size = load_vocabulary('vocabulary.json')
    print(f'Vocabulary size: {vocab_size}')
    
    # Load Quran data
    ayat = load_quran_data('../Muhaffez/quran-simple-min.txt')
    print(f'Total ayat: {len(ayat)}')
    
    # Create dataset and dataloader
    dataset = NoisyQuranDataset(ayat, vocabulary, max_length=100, noise_level=0.2)
    train_loader = DataLoader(dataset, batch_size=32, shuffle=True, num_workers=0)
    
    # Create model
    model = QuranMatcherModel(vocab_size=vocab_size, output_size=len(ayat))
    model = model.to(device)
    
    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    
    # Train model
    print('\nStarting training...\n')
    train_model(model, train_loader, criterion, optimizer, device, epochs=20)
    
    # Save model
    torch.save({
        'model_state_dict': model.state_dict(),
        'vocab_size': vocab_size,
        'output_size': len(ayat),
    }, 'quran_matcher_model.pth')
    print('\nModel saved to quran_matcher_model.pth')

if __name__ == '__main__':
    main()
