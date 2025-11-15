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

    return predicted_idx, confidence, top5, input_text

def main():
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
    print(f'Total ayat: {len(ayat)}')

    # Find Surah Al-Ma'idah (Surah 5)
    # Surah Al-Ma'idah starts at ayah index 677 (after Al-Nisa which has 176 ayat)
    # It has 120 ayat
    surah_start = 677
    surah_end = 677 + 120  # 797

    print(f'\nSurah Al-Ma\'idah: ayat {surah_start} to {surah_end - 1} (120 ayat)\n')

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

    # Test each ayah in Surah Al-Ma'idah
    correct = 0
    total = 0

    # Open file to save inputs
    with open('test_almaeda_inputs.txt', 'w', encoding='utf-8') as f:
        f.write('Testing Surah Al-Ma\'idah (120 ayat)\n')
        f.write('='*80 + '\n\n')

        for idx in range(surah_start, surah_end):
            ayah_text = ayat[idx]
            predicted_idx, confidence, top5, input_text = predict(model, ayah_text, vocabulary, device)

            total += 1
            is_correct = (predicted_idx == idx)
            if is_correct:
                correct += 1

            # Write to file
            f.write(f'Ayah {idx} (Al-Ma\'idah {idx - surah_start + 1}):\n')
            f.write(f'Original: {ayah_text}\n')
            f.write(f'Normalized (60 chars): {input_text}\n')
            f.write(f'Predicted: {predicted_idx} ({"✓ CORRECT" if is_correct else "✗ WRONG"})\n')
            f.write(f'Confidence: {confidence:.4f}\n')
            f.write(f'Top 5: {top5}\n')
            f.write('-'*80 + '\n\n')

            # Print progress
            if (idx - surah_start + 1) % 10 == 0:
                print(f'Tested {idx - surah_start + 1}/120 ayat - Accuracy so far: {100*correct/total:.2f}%')

    # Final results
    accuracy = 100 * correct / total
    print(f'\n{"="*80}')
    print(f'FINAL RESULTS:')
    print(f'Total ayat tested: {total}')
    print(f'Correct predictions: {correct}')
    print(f'Wrong predictions: {total - correct}')
    print(f'Accuracy: {accuracy:.2f}%')
    print(f'{"="*80}')
    print(f'\nResults saved to test_almaeda_inputs.txt')

if __name__ == '__main__':
    main()
