import torch
import sys
import os

# Add train directory to path to import seq2seq_model
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../train'))

from seq2seq_model import QuranSeq2SeqModel, load_vocabulary, load_quran_data


def normalize_arabic(text):
    """Normalize Arabic text - remove tashkeel and normalize hamza variants"""
    arabic_diacritics = set([
        '\u064B', '\u064C', '\u064D', '\u064E', '\u064F',
        '\u0650', '\u0651', '\u0652', '\u0653', '\u0654',
        '\u0655', '\u0656', '\u0657', '\u0658', '\u0670',
    ])

    text = ''.join(c for c in text if c not in arabic_diacritics)

    # Normalize hamza variants
    hamza_map = {
        'إ': 'ا', 'أ': 'ا', 'آ': 'ا',
        'ؤ': 'و', 'ئ': 'ي'
    }

    for old, new in hamza_map.items():
        text = text.replace(old, new)

    return text


def test_model(model_path, vocab_path, quran_path):
    """Test the trained model"""

    # Load vocabulary
    word_to_idx, idx_to_word, vocab_size = load_vocabulary(vocab_path)
    print(f'Vocabulary size: {vocab_size}')

    # Load model
    device = torch.device('mps' if torch.backends.mps.is_available() else 'cpu')
    print(f'Using device: {device}')

    model = QuranSeq2SeqModel(
        vocab_size=vocab_size,
        max_length=50,
        d_model=256,
        n_heads=8,
        n_layers=6,
        d_ff=1024,
        dropout=0.1
    )

    checkpoint = torch.load(model_path, map_location=device)
    model.load_state_dict(checkpoint['model'])
    model = model.to(device)
    model.eval()

    print(f'Model loaded from {model_path}')
    print(f'Model epoch: {checkpoint.get("epoch", "N/A") + 1}')
    print(f'Model accuracy: {checkpoint.get("accuracy", "N/A")}%')
    print(f'Model loss: {checkpoint.get("loss", "N/A")}')
    print()

    # Load Quran data
    ayat = load_quran_data(quran_path)
    print(f'Total ayat: {len(ayat)}')
    print()

    # Test with a few examples
    test_indices = [0, 1, 10, 100, 500, 1000, 5000]

    for idx in test_indices:
        if idx >= len(ayat):
            continue

        ayah = ayat[idx]
        words = normalize_arabic(ayah).split()

        if len(words) < 5:
            continue

        # Get first 10 words for input
        input_words = words[:10]
        expected_output_words = words[:5]

        # Build input sequence: القاريء: [input_words] الاية:
        reader_token = word_to_idx.get('القاريء:', 3)
        ayah_token = word_to_idx.get('الاية:', 4)
        unk_token = word_to_idx.get('<unk>', 0)

        input_tokens = [reader_token]
        for word in input_words:
            token = word_to_idx.get(word, unk_token)
            input_tokens.append(token)
        input_tokens.append(ayah_token)

        # Convert to tensor
        input_tensor = torch.tensor([input_tokens], dtype=torch.long).to(device)

        # Generate output (greedy decoding)
        with torch.no_grad():
            generated_tokens = input_tokens.copy()

            for _ in range(5):  # Generate 5 words
                current_input = torch.tensor([generated_tokens], dtype=torch.long).to(device)
                logits = model(current_input)

                # Get prediction for last position
                next_token_logits = logits[0, -1, :]
                next_token = torch.argmax(next_token_logits).item()

                generated_tokens.append(next_token)

        # Decode generated tokens (only the 5 words after الاية:)
        generated_word_tokens = generated_tokens[len(input_tokens):]
        generated_words = [idx_to_word.get(t, '<unk>') for t in generated_word_tokens]

        print(f'Ayah {idx+1}:')
        print(f'  Full ayah: {" ".join(words[:15])}...')
        print(f'  Input (first 10 words): {" ".join(input_words)}')
        print(f'  Expected output: {" ".join(expected_output_words)}')
        print(f'  Generated output: {" ".join(generated_words)}')
        print(f'  Match: {"✓" if generated_words == expected_output_words else "✗"}')
        print()


def main():
    model_path = '../train/checkpoint_best.pt'
    vocab_path = '../model/vocabulary.json'
    quran_path = '../../../Muhaffez/quran-simple-min.txt'

    if not os.path.exists(model_path):
        print(f'Error: Checkpoint file not found at {model_path}')
        print('Please train the model first using train.sh')
        return

    test_model(model_path, vocab_path, quran_path)


if __name__ == '__main__':
    main()
