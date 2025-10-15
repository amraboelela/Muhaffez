import torch
import coremltools as ct
from model import QuranMatcherModel, load_vocabulary
import json

print("Loading model and vocabulary...")

# Load vocabulary
vocabulary, vocab_size = load_vocabulary('vocabulary.json')
print(f"Vocabulary size: {vocab_size}")

# Load the offset model
checkpoint = torch.load('quran_matcher_model_offset.pth', map_location=torch.device('cpu'))

# Create model
model = QuranMatcherModel(
    vocab_size=checkpoint['vocab_size'],
    input_length=70,
    hidden_size=512,
    output_size=checkpoint['output_size']
)

# Load weights
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()

print(f"Model loaded - Output size: {checkpoint['output_size']} ayat")

# Create example input (70 token indices)
example_input = torch.randint(0, vocab_size, (1, 70), dtype=torch.long)

# Trace the model
print("Tracing model...")
traced_model = torch.jit.trace(model, example_input)

# Convert to CoreML
print("Converting to CoreML...")
coreml_model = ct.convert(
    traced_model,
    inputs=[ct.TensorType(name="input", shape=(1, 70), dtype=int)],
    outputs=[ct.TensorType(name="output")],
    minimum_deployment_target=ct.target.iOS15
)

# Set metadata
coreml_model.author = "Amr Aboelela"
coreml_model.license = "Muhaffez App"
coreml_model.short_description = "Aya Finder - identifies ayat from partial/noisy text"
coreml_model.version = "1.0"

# Save the model
output_path = "AyaFinder.mlpackage"
coreml_model.save(output_path)
print(f"✓ CoreML model saved to {output_path}")

# Also save vocabulary as a simple mapping for Swift
print("\n✓ Vocabulary already in vocabulary.json")
print(f"✓ Total ayat in model: {checkpoint['output_size']}")
print(f"\nModel info:")
print(f"  - Input: 70 token indices (character-level)")
print(f"  - Output: {checkpoint['output_size']} probabilities (one per ayah)")
print(f"  - Vocabulary: {vocab_size} tokens")
