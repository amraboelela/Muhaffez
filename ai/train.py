import json
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from model import QuranMatcherModel, QuranAyahDataset, load_quran_data, load_vocabulary
import random
import time

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

class CleanQuranDataset(QuranAyahDataset):
    """Dataset that uses first 70 characters of ayat without noise"""
    def __init__(self, ayat_list, vocabulary, max_length=70):
        super().__init__(ayat_list, vocabulary, max_length)

    def __getitem__(self, idx):
        ayah = self.ayat[idx]

        # Use first 70 characters (no noise)
        clean_ayah = ayah[:70]
        tokens = self.tokenize(clean_ayah)

        x = torch.tensor(tokens, dtype=torch.long)
        y = torch.tensor(idx, dtype=torch.long)

        return x, y

def train_model(model, train_loader, criterion, optimizer, scheduler, device, epochs=10, save_inputs=False, ayat_list=None, vocabulary=None, vocab_size=None, output_size=None):
    """Train the model"""
    model.train()

    # Track best model
    best_accuracy = 0.0
    best_model_state = None

    # Open file to save training inputs if requested
    input_file = None
    token_to_char = None
    saved_ayat = set()  # Track which ayat we've saved
    target_count = len(ayat_list) if ayat_list else 0

    if save_inputs:
        input_file = open('training_inputs.txt', 'w', encoding='utf-8')
        input_file.write('# Training inputs (first 70 characters, no distortions)\n')
        input_file.write('# Format: Ayah Index -> Input -> Target\n\n')

        # Create reverse vocabulary mapping
        if vocabulary:
            token_to_char = {v: k for k, v in vocabulary.items()}

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

            # Save training inputs until we have all ayat
            if save_inputs and input_file and token_to_char and len(saved_ayat) < target_count:
                for i in range(len(data)):
                    target_idx = target[i].item()

                    # Only save if we haven't saved this ayah yet
                    if target_idx not in saved_ayat:
                        # Decode tokens back to text
                        tokens = data[i].cpu().numpy()
                        # Remove padding and convert to characters
                        chars = []
                        for t in tokens:
                            if t == 0:  # PAD token
                                break
                            if t in token_to_char:
                                chars.append(token_to_char[t])

                        input_text = ''.join(chars)

                        if ayat_list:
                            input_file.write(f"Ayah Index: {target_idx}\n")
                            input_file.write(f"Input: {input_text}\n")
                            input_file.write(f"Target: {ayat_list[target_idx]}\n\n")

                            saved_ayat.add(target_idx)

            if batch_idx % 100 == 0:
                coverage = f", Coverage: {len(saved_ayat)}/{target_count}" if save_inputs else ""
                print(f'Epoch: {epoch+1}/{epochs}, Batch: {batch_idx}/{len(train_loader)}, '
                      f'Loss: {loss.item():.4f}, Acc: {100*correct/total:.2f}%{coverage}')

        avg_loss = total_loss / len(train_loader)
        accuracy = 100 * correct / total
        coverage_msg = f", Saved: {len(saved_ayat)}/{target_count}" if save_inputs else ""
        print(f'\nEpoch {epoch+1} Summary: Avg Loss: {avg_loss:.4f}, Accuracy: {accuracy:.2f}%, LR: {scheduler.get_last_lr()[0]:.6f}{coverage_msg}\n')

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
                }, 'quran_matcher_model.pth')
                print(f'✓ New best model saved! Accuracy: {best_accuracy:.2f}%')

        # Step the scheduler
        scheduler.step(avg_loss)

        # Stop saving if we have all ayat
        if save_inputs and len(saved_ayat) >= target_count:
            if input_file:
                input_file.close()
                input_file = None
                print(f'\n✓ All {target_count} ayat saved to training_inputs.txt\n')

    if input_file:
        input_file.close()
        print(f'\n✓ Training inputs saved: {len(saved_ayat)}/{target_count} ayat')

    print(f'\n✓ Best accuracy achieved: {best_accuracy:.2f}%')
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
    vocabulary, vocab_size = load_vocabulary('vocabulary.json')
    print(f'Vocabulary size: {vocab_size}')
    
    # Load Quran data
    ayat = load_quran_data('../Muhaffez/quran-simple-min.txt')
    print(f'Total ayat: {len(ayat)}')
    
    # Create dataset and dataloader
    dataset = CleanQuranDataset(ayat, vocabulary, max_length=70)
    # Shuffle for better training, will save all ayat across epochs
    train_loader = DataLoader(dataset, batch_size=64, shuffle=True, num_workers=0)

    # Create model with larger hidden size and 70 input length
    model = QuranMatcherModel(vocab_size=vocab_size, input_length=70, hidden_size=512, output_size=len(ayat))

    # Try to load existing model weights
    import os
    if os.path.exists('quran_matcher_model.pth'):
        print('Loading existing model weights from quran_matcher_model.pth...')
        checkpoint = torch.load('quran_matcher_model.pth', map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])
        print('Model weights loaded successfully!')
    else:
        print('No existing model found, starting from scratch')

    model = model.to(device)

    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.0005)  # Lower LR for fine-tuning

    # Learning rate scheduler - reduce LR when loss plateaus
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=5)

    # Train model
    print('\nContinuing training...\n')
    best_acc = train_model(model, train_loader, criterion, optimizer, scheduler, device, epochs=100, save_inputs=True, ayat_list=ayat, vocabulary=vocabulary, vocab_size=vocab_size, output_size=len(ayat))

    print(f'\n✓ Training complete! Best model saved to quran_matcher_model.pth with accuracy: {best_acc:.2f}%')

if __name__ == '__main__':
    main()
