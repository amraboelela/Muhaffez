#!/usr/bin/env python3
"""
Unit tests for specific ayah inputs - mirrors the iOS Swift tests
Tests the PyTorch model with the same inputs as the iOS AyaFinderMLModelTests
"""
import torch
import sys
import os

# Add parent directories to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))

from seq2seq_model import QuranSeq2SeqModel, load_vocabulary


def predict_ayah(model, word_to_idx, idx_to_word, input_text, device, max_length=50):
    """
    Predict ayah completion from input text
    Mirrors the Swift AyaFinderMLModel.predict() function

    Args:
        model: The trained model
        word_to_idx: Word to index mapping
        idx_to_word: Index to word mapping
        input_text: Input Arabic text
        device: torch device
        max_length: Maximum sequence length

    Returns:
        Predicted ayah text (first 6 words) or None
    """
    # Get special tokens
    bos_token = word_to_idx['<s>']
    eos_token = word_to_idx['</s>']
    reader_token = word_to_idx['القاريء:']
    ayah_token = word_to_idx['الاية:']
    pad_token = word_to_idx.get('<pad>', 0)

    # Split input into words
    input_words = input_text.split()

    if not input_words:
        print("No input words")
        return None

    # Limit to first 6 words to leave room for output
    input_words = input_words[:6]

    # Build sequence: <s> القاريء: [input_words] الاية:
    sequence_tokens = [bos_token, reader_token]

    for word in input_words:
        if word in word_to_idx:
            token = word_to_idx[word]
            sequence_tokens.append(token)
        else:
            print(f"Warning: word '{word}' not in vocabulary, skipping")

    sequence_tokens.append(ayah_token)

    print(f"Sequence length before padding: {len(sequence_tokens)}")

    # Pad to max_length
    attention_mask = [1] * len(sequence_tokens) + [0] * (max_length - len(sequence_tokens))
    sequence_tokens += [pad_token] * (max_length - len(sequence_tokens))

    # Convert to tensors
    input_tensor = torch.tensor([sequence_tokens], dtype=torch.long).to(device)
    attention_mask_tensor = torch.tensor([attention_mask], dtype=torch.long).to(device)

    # Get model predictions
    with torch.no_grad():
        logits = model(input_tensor, attention_mask=attention_mask_tensor)
        predictions = torch.argmax(logits, dim=-1)

    # Find position of الاية: marker
    ayah_pos = sequence_tokens.index(ayah_token)
    print(f"Ayah marker position: {ayah_pos}")

    # Get predicted tokens for 6 output positions after الاية:
    output_length = 6
    predicted_words = []

    for i in range(output_length):
        pos = ayah_pos + i
        if pos >= max_length:
            break

        pred_token = predictions[0, pos].item()

        # Convert token to word
        word = idx_to_word.get(pred_token, '?')

        # Skip special tokens in output
        if word not in ['<s>', '</s>', 'القاريء:', 'الاية:', '<pad>']:
            predicted_words.append(word)

    predicted_text = ' '.join(predicted_words)
    print(f"Predicted ayah text: {predicted_text}")

    return predicted_text


def test_distorted_input(model, word_to_idx, idx_to_word, device):
    """
    Test with distorted input: "فاعص" instead of "فوق"
    Expected ayah: "وهو القاهر فوق عباده وهو الحكيم الخبير" (Al-An'am 6:18)
    """
    print("\n" + "="*80)
    print("TEST: Distorted Input")
    print("="*80)

    input_text = "وهو القاهر فاعص عباده"
    print(f"Input: {input_text}")

    result = predict_ayah(model, word_to_idx, idx_to_word, input_text, device)

    if result:
        # Verify result contains key words
        assert "القاهر" in result, f"Result should contain القاهر, got: {result}"
        assert "عباده" in result, f"Result should contain عباده, got: {result}"

        words = result.split()
        assert len(words) >= 2, f"Result should have at least 2 words, got {len(words)}"

        print("✓ PASSED: Distorted input test")
        return True
    else:
        print("⚠ Model returned None (distortion may be too severe)")
        return False


def test_correct_input(model, word_to_idx, idx_to_word, device):
    """
    Test with correct input for Al-An'am 6:18
    """
    print("\n" + "="*80)
    print("TEST: Correct Input")
    print("="*80)

    input_text = "وهو القاهر فوق عباده"
    print(f"Input: {input_text}")

    result = predict_ayah(model, word_to_idx, idx_to_word, input_text, device)

    assert result is not None, "Model should return a result for valid input"

    # Should contain input words
    assert "القاهر" in result, f"Result should contain القاهر, got: {result}"
    assert "عباده" in result, f"Result should contain عباده, got: {result}"

    # Expected continuation: "وهو الحكيم الخبير" or similar
    words = result.split()
    assert len(words) >= 4, f"Result should have at least 4 words, got {len(words)}"

    print("✓ PASSED: Correct input test")
    return True


def test_word_array_input(model, word_to_idx, idx_to_word, device):
    """
    Test with word array: ["وهو", "القاهر", "فاعص", "عباده"]
    Expected: Should recognize this as Al-An'am 6:18 despite "فاعص" distortion
    """
    print("\n" + "="*80)
    print("TEST: Word Array Input")
    print("="*80)

    input_words = ["وهو", "القاهر", "فاعص", "عباده"]
    input_text = " ".join(input_words)

    print(f"Input words: {input_words}")
    print(f"Joined text: {input_text}")

    result = predict_ayah(model, word_to_idx, idx_to_word, input_text, device)

    if result:
        # Should contain key words (model corrects distortion)
        assert "القاهر" in result, f"Result should contain القاهر, got: {result}"
        assert "عباده" in result, f"Result should contain عباده, got: {result}"

        words = result.split()
        assert len(words) >= 2, f"Result should have at least 2 words, got {len(words)}"

        print("✓ PASSED: Word array input test")
        return True
    else:
        print("⚠ Model returned None (distortion may be too severe)")
        return False


def test_partial_match(model, word_to_idx, idx_to_word, device):
    """
    Test with partial input (first three words only)
    """
    print("\n" + "="*80)
    print("TEST: Partial Match")
    print("="*80)

    input_text = "وهو القاهر فوق"
    print(f"Input: {input_text}")

    result = predict_ayah(model, word_to_idx, idx_to_word, input_text, device)

    assert result is not None, "Model should handle partial input"

    # Should continue the ayah
    assert "القاهر" in result, f"Result should contain القاهر, got: {result}"

    # Should predict continuation (like "عباده وهو الحكيم الخبير")
    words = result.split()
    assert len(words) >= 3, f"Result should continue with at least 3 words, got {len(words)}"

    print("✓ PASSED: Partial match test")
    return True


def main():
    """Run all tests"""
    print("="*80)
    print("Quran Seq2Seq Model - Specific Input Tests")
    print("Mirrors iOS AyaFinderMLModelTests")
    print("="*80)

    model_path = '../model/quran_seq2seq_model.pt'
    vocab_path = '../model/vocabulary.json'

    if not os.path.exists(model_path):
        print(f'Error: Model file not found at {model_path}')
        print('Please train the model first using train.sh')
        return

    if not os.path.exists(vocab_path):
        print(f'Error: Vocabulary file not found at {vocab_path}')
        return

    # Load vocabulary
    word_to_idx, idx_to_word, vocab_size = load_vocabulary(vocab_path)
    print(f'Vocabulary size: {vocab_size}')
    print(f'Special tokens: <pad>={word_to_idx.get("<pad>")}, <s>={word_to_idx.get("<s>")}, </s>={word_to_idx.get("</s>")}, القاريء:={word_to_idx.get("القاريء:")}, الاية:={word_to_idx.get("الاية:")}')

    # Set device
    if torch.backends.mps.is_available():
        device = torch.device('mps')
        print('🚀 Using Metal GPU (Apple Silicon)')
    elif torch.cuda.is_available():
        device = torch.device('cuda')
        print('🚀 Using CUDA GPU')
    else:
        device = torch.device('cpu')
        print('Using CPU')

    # Load model
    print(f'\nLoading model from {model_path}...')
    model = QuranSeq2SeqModel(
        vocab_size=vocab_size,
        max_length=50,
        d_model=128,
        n_heads=4,
        n_layers=4,
        d_ff=512,
        dropout=0.1
    )

    checkpoint = torch.load(model_path, map_location=device)

    # Handle both old and new checkpoint formats
    if 'model' in checkpoint:
        model.load_state_dict(checkpoint['model'])
    elif 'model_state_dict' in checkpoint:
        model.load_state_dict(checkpoint['model_state_dict'])
    else:
        model.load_state_dict(checkpoint)

    model.to(device)
    model.eval()

    print(f'Model loaded successfully!')
    if 'epoch' in checkpoint:
        print(f'  Epoch: {checkpoint["epoch"]}')
    if 'accuracy' in checkpoint:
        print(f'  Accuracy: {checkpoint["accuracy"]}')

    # Run tests
    passed = 0
    total = 4

    try:
        if test_distorted_input(model, word_to_idx, idx_to_word, device):
            passed += 1
    except AssertionError as e:
        print(f"✗ FAILED: {e}")

    try:
        if test_correct_input(model, word_to_idx, idx_to_word, device):
            passed += 1
    except AssertionError as e:
        print(f"✗ FAILED: {e}")

    try:
        if test_word_array_input(model, word_to_idx, idx_to_word, device):
            passed += 1
    except AssertionError as e:
        print(f"✗ FAILED: {e}")

    try:
        if test_partial_match(model, word_to_idx, idx_to_word, device):
            passed += 1
    except AssertionError as e:
        print(f"✗ FAILED: {e}")

    # Summary
    print("\n" + "="*80)
    print(f"TEST SUMMARY: {passed}/{total} tests passed")
    print("="*80)

    if passed == total:
        print("✓ All tests passed!")
        return 0
    else:
        print(f"✗ {total - passed} test(s) failed")
        return 1


if __name__ == '__main__':
    exit(main())
