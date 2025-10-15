import torch
import coremltools as ct
from model import QuranMatcherModel, load_vocabulary
import json

print("Converting PyTorch model to CoreML...")

# Load vocabulary
vocabulary, vocab_size = load_vocabulary('vocabulary_normalized.json')
print(f'Vocabulary size: {vocab_size}')

# Model parameters
input_length = 60
hidden_size = 512

# Load the trained model
checkpoint = torch.load('quran_matcher_model_normalized.pth', map_location='cpu')
output_size = checkpoint['output_size']
print(f'Output size: {output_size}')
print(f'Training accuracy: {checkpoint.get("accuracy", "N/A")}%')

# Create model
model = QuranMatcherModel(
    vocab_size=vocab_size,
    input_length=input_length,
    hidden_size=hidden_size,
    output_size=output_size
)
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()

print('\nModel architecture:')
print(model)

# Create example input
example_input = torch.randint(0, vocab_size, (1, input_length), dtype=torch.long)

# Trace the model
print('\nTracing model...')
traced_model = torch.jit.trace(model, example_input)

# Convert to CoreML
print('Converting to CoreML...')
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.TensorType(name="input", shape=(1, input_length), dtype=int)],
    outputs=[ct.TensorType(name="output")],
    minimum_deployment_target=ct.target.iOS15,
)

# Set model metadata
mlmodel.short_description = "Quran Ayah Matcher - Normalized Text (60 chars, 34 vocab)"
mlmodel.author = "Amr Aboelela"
mlmodel.license = "MIT"
mlmodel.version = "2.0"

# Add input/output descriptions
mlmodel.input_description["input"] = "Tokenized Arabic text (60 characters, normalized)"
mlmodel.output_description["output"] = "Logits for each ayah (6203 classes)"

# Save the model
output_path = 'AyaFinder.mlpackage'
mlmodel.save(output_path)
print(f'\n✓ Model saved to {output_path}')

# Print model info
print(f'\nModel Info:')
print(f'  Input shape: (1, {input_length})')
print(f'  Output shape: (1, {output_size})')
print(f'  Vocab size: {vocab_size}')
print(f'  Model size: ~{sum(p.numel() for p in model.parameters()) / 1e6:.2f}M parameters')

# Save vocabulary for Swift
vocab_for_swift = {
    'char_to_token': vocabulary,
    'vocab_size': vocab_size,
    'input_length': input_length,
    'output_size': output_size
}

with open('vocabulary_normalized_swift.json', 'w', encoding='utf-8') as f:
    json.dump(vocab_for_swift, f, ensure_ascii=False, indent=2)

print(f'✓ Vocabulary saved to vocabulary_normalized_swift.json')
print('\nConversion complete\!')
