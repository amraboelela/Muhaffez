import torch
import json
from model import QuranMatcherModel

print("Converting 47-vocab model to 34-vocab model...")

# Load both vocabularies
with open('vocabulary.json', 'r', encoding='utf-8') as f:
    old_vocab = json.load(f)['char_to_token']
print(f"Old vocabulary size: {len(old_vocab)}")

with open('vocabulary_normalized.json', 'r', encoding='utf-8') as f:
    new_vocab_data = json.load(f)
    new_vocab = new_vocab_data['char_to_token']
    new_vocab_size = new_vocab_data['vocab_size']
print(f"New vocabulary size: {new_vocab_size}")

# Load the 60-char normalized model (47 vocab)
checkpoint = torch.load('quran_matcher_model_normalized.pth', map_location=torch.device('cpu'))
print(f"Loaded model - Accuracy: {checkpoint.get('accuracy', 'N/A')}%")

# Create new model with smaller vocabulary
model_new = QuranMatcherModel(
    vocab_size=new_vocab_size,
    input_length=60,
    hidden_size=512,
    output_size=checkpoint['output_size']
)

# Get state dicts
old_state = checkpoint['model_state_dict']
new_state = model_new.state_dict()

# Create mapping from old vocab tokens to new vocab tokens
token_mapping = {}
for char, old_token_id in old_vocab.items():
    if char in new_vocab:
        new_token_id = new_vocab[char]
        token_mapping[old_token_id] = new_token_id
    elif char in ['<PAD>', '<UNK>']:
        # Special tokens should match
        token_mapping[old_token_id] = new_vocab[char]

print(f"\nToken mapping created: {len(token_mapping)} tokens mapped")

# Transfer weights
for name, param in new_state.items():
    if name == 'embedding.weight':
        # Old: (47, 64), New: (34, 64)
        print(f"Transferring embedding.weight: {old_state[name].shape} -> {param.shape}")
        old_embeddings = old_state[name]

        # Initialize new embeddings with Xavier initialization
        new_embeddings = torch.nn.init.xavier_uniform_(torch.empty(new_vocab_size, 64))

        # Copy embeddings for tokens that exist in both vocabularies
        for old_token, new_token in token_mapping.items():
            if old_token < old_embeddings.size(0) and new_token < new_embeddings.size(0):
                new_embeddings[new_token] = old_embeddings[old_token].clone()

        new_state[name] = new_embeddings
        print(f"  Transferred {len(token_mapping)} token embeddings")

    elif name == 'fc1.weight':
        # Old: (512, 60*64=3840), New: (512, 60*64=3840) - same size!
        # Wait, if vocab changed, this should change too... let me recalculate
        old_input_size = old_state[name].shape[1]  # Should be 60*64 = 3840
        new_input_size = 60 * 64  # Still 3840

        print(f"fc1.weight: {old_state[name].shape} -> {param.shape}")

        if old_input_size == new_input_size:
            # Same size, just copy
            new_state[name] = old_state[name].clone()
        else:
            print(f"  Error: Size mismatch!")

    else:
        # Copy all other layers as-is
        if old_state[name].shape == param.shape:
            new_state[name] = old_state[name].clone()
        else:
            print(f"  Warning: Shape mismatch for {name}: {old_state[name].shape} != {param.shape}")

# Load the new weights
model_new.load_state_dict(new_state)

# Save the converted model
torch.save({
    'model_state_dict': model_new.state_dict(),
    'vocab_size': new_vocab_size,
    'output_size': checkpoint['output_size'],
    'accuracy': None,  # Will need retraining
    'converted_from': '47vocab_to_34vocab'
}, 'quran_matcher_model_34vocab.pth')

print(f"\n✓ Converted model saved to quran_matcher_model_34vocab.pth")
print(f"  Vocabulary: 47 -> 34 tokens")
print(f"  Embedding layer: (47, 64) -> (34, 64)")
print(f"  Input length: 60 chars")
print(f"  Output: {checkpoint['output_size']} ayat")
print(f"\nReady for retraining with smaller vocabulary!")
