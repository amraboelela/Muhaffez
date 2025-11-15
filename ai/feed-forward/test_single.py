import torch
from model import QuranMatcherModel, load_quran_data, load_vocabulary
import unicodedata

def remove_tashkeel(text):
    """Remove Arabic diacritics (tashkeel)"""
    arabic_diacritics = set([
        '\u064B',  # Fathatan
        '\u064C',  # Dammatan
        '\u064D',  # Kasratan
        '\u064E',  # Fatha
        '\u064F',  # Damma
        '\u0650',  # Kasra
        '\u0651',  # Shadda
        '\u0652',  # Sukun
        '\u0653',  # Maddah
        '\u0654',  # Hamza above
        '\u0655',  # Hamza below
        '\u0656',  # Subscript alef
        '\u0657',  # Inverted damma
        '\u0658',  # Mark noon ghunna
        '\u0670',  # Superscript alef
    ])
    return ''.join(c for c in text if c not in arabic_diacritics)

def normalize_arabic(text):
    """Normalize Arabic text - remove tashkeel and normalize hamza variants"""
    text = remove_tashkeel(text)
    hamza_map = {
        'إ': 'ا', 'أ': 'ا', 'آ': 'ا',
        'ؤ': 'و', 'ئ': 'ي'
    }
    for old, new in hamza_map.items():
        text = text.replace(old, new)
    return text

def tokenize(text, vocabulary, max_length=60):
    """Convert text to token indices"""
    pad_token = vocabulary.get('<PAD>', 0)
    unk_token = vocabulary.get('<UNK>', 1)

    tokens = []
    for char in text:
        token = vocabulary.get(char, unk_token)
        tokens.append(token)

    # Pad or truncate to max_length
    if len(tokens) < max_length:
        tokens.extend([pad_token] * (max_length - len(tokens)))
    else:
        tokens = tokens[:max_length]

    return tokens

def predict(model, text, vocabulary, device):
    """Predict ayah index for given text"""
    # Normalize text
    normalized_text = normalize_arabic(text)

    # Take first 60 chars
    input_text = normalized_text[:60]

    # Tokenize
    tokens = tokenize(input_text, vocabulary, max_length=60)

    # Convert to tensor
    x = torch.tensor([tokens], dtype=torch.long).to(device)

    # Predict
    model.eval()
    with torch.no_grad():
        output = model(x)

        # Get top prediction
        _, predicted = torch.max(output.data, 1)
        predicted_idx = predicted.item()

        # Get probabilities using softmax
        probabilities = torch.nn.functional.softmax(output[0], dim=0)
        confidence = probabilities[predicted_idx].item()

        # Get top 5 predictions
        top5_probs, top5_indices = torch.topk(probabilities, 5)
        top5 = [(idx.item(), prob.item()) for idx, prob in zip(top5_indices, top5_probs)]

    return predicted_idx, confidence, top5, input_text, normalized_text

def main():
    # Test text
    test_text = "أَيُّهَا الَّذينَ آمَنوا لا تَتَّخِذُوا اليَهودَ وَالنَّصارىٰ أَولِياءَ بَعضُهُم أَولِيا"

    # Set device
    if torch.backends.mps.is_available():
        device = torch.device('mps')
    elif torch.cuda.is_available():
        device = torch.device('cuda')
    else:
        device = torch.device('cpu')
    print(f'Using device: {device}')

    # Load vocabulary
    vocabulary, vocab_size = load_vocabulary('vocabulary_normalized.json')
    print(f'Vocabulary size: {vocab_size}')

    # Load Quran data
    ayat = load_quran_data('../Muhaffez/quran-simple-min.txt')
    print(f'Total ayat: {len(ayat)}\n')

    # Load model
    checkpoint = torch.load('quran_matcher_model_normalized.pth', map_location=device)
    model = QuranMatcherModel(
        vocab_size=vocab_size,
        input_length=60,
        hidden_size=512,
        output_size=len(ayat)
    )
    model.load_state_dict(checkpoint['model_state_dict'])
    model = model.to(device)
    model.eval()

    print(f'Model loaded - Training accuracy: {checkpoint.get("accuracy", "N/A")}%\n')
    print('='*80)

    # Test the text
    predicted_idx, confidence, top5, input_text, normalized_full = predict(model, test_text, vocabulary, device)

    print(f'Test Text:')
    print(f'  Original: {test_text}')
    print(f'  Normalized (full): {normalized_full}')
    print(f'  Input (60 chars): {input_text}')
    print(f'\nPrediction:')
    print(f'  Predicted Index: {predicted_idx}')
    print(f'  Confidence: {confidence:.4f} ({confidence*100:.2f}%)')
    print(f'\nTop 5 Predictions:')
    for i, (idx, prob) in enumerate(top5, 1):
        print(f'  {i}. Index {idx}: {prob:.4f} ({prob*100:.2f}%)')
        # Show first 80 chars of the ayah
        ayah_text = ayat[idx][:80]
        print(f'     {ayah_text}...')

    print('\n' + '='*80)
    print(f'\nPredicted Ayah (Index {predicted_idx}):')
    print(f'{ayat[predicted_idx]}')

if __name__ == '__main__':
    main()
