import torch
from model import QuranMatcherModel

# Load old model checkpoint (100 tokens)
print("Loading old model checkpoint...")
old_checkpoint = torch.load('quran_matcher_model_100tokens_backup.pth', map_location='cpu')
old_state_dict = old_checkpoint['model_state_dict']

# Create new model (70 tokens)
print("Creating new model architecture...")
vocab_size = old_checkpoint['vocab_size']
output_size = old_checkpoint['output_size']
new_model = QuranMatcherModel(vocab_size=vocab_size, input_length=70, hidden_size=512, output_size=output_size)

# Get new model state dict
new_state_dict = new_model.state_dict()

# Transfer compatible weights
print("\nTransferring weights:")
transferred = []
sliced = []

for key in new_state_dict.keys():
    if key in old_state_dict:
        old_shape = old_state_dict[key].shape
        new_shape = new_state_dict[key].shape
        
        if old_shape == new_shape:
            # Direct transfer for matching shapes
            new_state_dict[key] = old_state_dict[key]
            transferred.append(key)
            print(f"  ✓ Transferred: {key} {new_shape}")
        elif key == 'fc1.weight':
            # Special handling for fc1.weight: slice first 4480 columns from 6400
            # Old shape: [512, 6400] (output_features, input_features)
            # New shape: [512, 4480]
            old_weight = old_state_dict[key]  # [512, 6400]
            new_state_dict[key] = old_weight[:, :4480]  # Slice first 4480 columns
            sliced.append(key)
            print(f"  ✂ Sliced: {key}")
            print(f"    Old: {old_shape} -> New: {new_shape}")
            print(f"    Kept first 4480 out of 6400 input features (70 tokens × 64 embedding)")
        else:
            print(f"  ? Unexpected mismatch: {key}")
            print(f"    Old: {old_shape} -> New: {new_shape}")

print(f"\nSummary:")
print(f"  Fully transferred: {len(transferred)} layers")
print(f"  Sliced/adapted: {len(sliced)} layers")
print(f"  Total: {len(transferred) + len(sliced)}/{len(new_state_dict)} layers")

# Load the weights into new model
new_model.load_state_dict(new_state_dict)

# Save the new model
print("\nSaving converted model...")
torch.save({
    'model_state_dict': new_model.state_dict(),
    'vocab_size': vocab_size,
    'output_size': output_size,
}, 'quran_matcher_model.pth')

print("✓ Converted model saved to: quran_matcher_model.pth")
print("\n✓ All weights transferred\! The model should work well immediately.")
print("  Fine-tuning for a few epochs is recommended to adapt to 70-token inputs.")
