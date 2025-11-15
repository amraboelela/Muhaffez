import torch
from model import QuranMatcherModel

print("Converting 70-char model to 60-char model...")

# Load the 70-char offset model
checkpoint = torch.load('quran_matcher_model_offset.pth', map_location=torch.device('cpu'))
print(f"Loaded 70-char model - Accuracy: {checkpoint.get('accuracy', 'N/A')}")

# Create new 60-char model
model_60 = QuranMatcherModel(
    vocab_size=checkpoint['vocab_size'],
    input_length=60,
    hidden_size=512,
    output_size=checkpoint['output_size']
)

# Get the state dicts
old_state = checkpoint['model_state_dict']
new_state = model_60.state_dict()

# Copy weights
for name, param in new_state.items():
    if name == 'fc1.weight':
        # Old: (512, 70*64=4480), New: (512, 60*64=3840)
        # Keep first 3840 columns (first 60 characters)
        print(f"Slicing fc1.weight: {old_state[name].shape} -> {param.shape}")
        new_state[name] = old_state[name][:, :3840].clone()
    elif name == 'fc1.bias':
        # Bias stays the same
        new_state[name] = old_state[name].clone()
    else:
        # Copy other layers as-is
        new_state[name] = old_state[name].clone()

# Load the new weights
model_60.load_state_dict(new_state)

# Save the converted model
torch.save({
    'model_state_dict': model_60.state_dict(),
    'vocab_size': checkpoint['vocab_size'],
    'output_size': checkpoint['output_size'],
    'accuracy': None,  # Will be retrained
    'converted_from': '70char_offset_model'
}, 'quran_matcher_model_60char.pth')

print(f"✓ Converted model saved to quran_matcher_model_60char.pth")
print(f"  Input length: 70 -> 60 chars")
print(f"  fc1 layer: 4480 -> 3840 input features")
print(f"  Vocabulary: {checkpoint['vocab_size']} tokens")
print(f"  Output: {checkpoint['output_size']} ayat")
