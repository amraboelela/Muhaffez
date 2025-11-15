import json
import torch
import torch.nn.functional as F
from model import QuranMatcherModel, load_quran_data, load_vocabulary

# Load model
checkpoint = torch.load('quran_matcher_model.pth', map_location=torch.device('cpu'))
vocabulary, vocab_size = load_vocabulary('vocabulary.json')
ayat = load_quran_data('../Muhaffez/quran-simple-min.txt')

model = QuranMatcherModel(
    vocab_size=checkpoint['vocab_size'],
    input_length=70,
    hidden_size=512,
    output_size=checkpoint['output_size']
)
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()

print(f"Model loaded! Total ayat: {len(ayat)}")

# Find Al-Maeda (surah 5) - it starts after An-Nisa
# Al-Maeda starts with "أَوفوا بِالعُقودِ"
maeda_start = None
for i, ayah in enumerate(ayat):
    if "أَوفوا بِالعُقودِ" in ayah:
        maeda_start = i
        print(f"Found Al-Maeda start at index: {maeda_start}")
        break

if maeda_start is None:
    print("Could not find Al-Maeda!")
    exit(1)

# Test 100 ayat starting from ayah 51 (index 50 from maeda_start)
start_idx = maeda_start + 50  # Ayah 51 is at index 50
end_idx = min(start_idx + 100, len(ayat))

print(f"\nTesting {end_idx - start_idx} ayat from Al-Maeda starting at ayah 51")
print("="*80)

def tokenize(text, max_length=70):
    """Convert text to token indices"""
    tokens = []
    pad_token = vocabulary.get('<PAD>', 0)
    unk_token = vocabulary.get('<UNK>', 1)

    for char in text:
        token = vocabulary.get(char, unk_token)
        tokens.append(token)

    # Pad or truncate to max_length
    if len(tokens) < max_length:
        tokens.extend([pad_token] * (max_length - len(tokens)))
    else:
        tokens = tokens[:max_length]

    return tokens

correct = 0
total = 0

for idx in range(start_idx, end_idx):
    ayah = ayat[idx]
    tokens = tokenize(ayah)
    x = torch.tensor([tokens], dtype=torch.long)

    with torch.no_grad():
        output = model(x)
        probabilities = F.softmax(output, dim=1)[0]

    # Get top prediction
    top_prob, top_idx = torch.topk(probabilities, 1)
    predicted_idx = top_idx[0].item()
    probability = top_prob[0].item()

    total += 1
    if predicted_idx == idx:
        correct += 1
        status = "✓"
    else:
        status = "✗"

    if total <= 10 or predicted_idx != idx:  # Show first 10 and all errors
        print(f"\n{status} Ayah {total} (Index: {idx})")
        print(f"  Predicted: {predicted_idx} (Prob: {probability:.4f})")
        if predicted_idx != idx:
            print(f"  Input:     {ayah[:70]}...")
            print(f"  Predicted: {ayat[predicted_idx][:70]}...")

accuracy = 100 * correct / total
print(f"\n{'='*80}")
print(f"Results: {correct}/{total} correct")
print(f"Accuracy: {accuracy:.2f}%")
