#!/usr/bin/env python3
"""
Unit tests for specific ayah inputs - mirrors the iOS Swift tests
Tests the PyTorch model with the same inputs as the iOS AyaFinderMLModelTests
Uses autoregressive generation (NO PADDING) like test_ayah_618.py
"""
import torch
import sys
import os

# Add parent directories to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))

from seq2seq_model import QuranSeq2SeqModel, load_vocabulary


def predict_ayah(model, word_to_idx, idx_to_word, input_text, device, max_output_words=6):
    """
    Predict ayah completion from input text using autoregressive generation
    TRUE INFERENCE - predicts one token at a time without padding

    Args:
        model: The trained model
        word_to_idx: Word to index mapping
        idx_to_word: Index to word mapping
        input_text: Input Arabic text
        device: torch device
        max_output_words: Maximum number of output words to generate

    Returns:
        Predicted ayah text or None
    """
    # Get special tokens
    bos_token = word_to_idx['<s>']
    eos_token = word_to_idx['</s>']
    reader_token = word_to_idx['القاريء:']
    ayah_token = word_to_idx['الاية:']

    # Split input into words
    input_words = input_text.split()

    if not input_words:
        print("No input words")
        return None

    # Limit to first 6 words
    input_words = input_words[:6]

    # Build initial sequence: <s> القاريء: [input_words] الاية:
    sequence_tokens = [bos_token, reader_token]

    for word in input_words:
        if word in word_to_idx:
            token = word_to_idx[word]
            sequence_tokens.append(token)

    sequence_tokens.append(ayah_token)

    print(f"Initial sequence length: {len(sequence_tokens)} (before generation)")

    # Autoregressive generation: predict one token at a time
    predicted_words = []

    for i in range(max_output_words):
        # Convert current sequence to tensor (NO PADDING)
        input_tensor = torch.tensor([sequence_tokens], dtype=torch.long).to(device)
        attention_mask_tensor = torch.ones_like(input_tensor).to(device)

        # Get model predictions
        with torch.no_grad():
            logits = model(input_tensor, attention_mask=attention_mask_tensor)
            predictions = torch.argmax(logits, dim=-1)

        # Get prediction for the last position (next token to generate)
        next_token = predictions[0, -1].item()

        # Stop if we predict </s>
        if next_token == eos_token:
            break

        # Convert token to word
        word = idx_to_word.get(next_token, '?')

        # Append to sequence for next iteration
        sequence_tokens.append(next_token)

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


def test_an_nas(model, word_to_idx, idx_to_word, device):
    """
    Test with Surat An-Nas first ayah
    Input: "قل اعوذ برب الناس"
    Expected: Should recognize as An-Nas 114:1 (ayah index 6197)
    """
    print("\n" + "="*80)
    print("TEST: Surat An-Nas")
    print("="*80)

    input_text = "قل اعوذ برب الناس"
    print(f"Input: {input_text}")

    result = predict_ayah(model, word_to_idx, idx_to_word, input_text, device)

    assert result is not None, "Model should return a result for An-Nas"

    # Should contain key words from the input
    assert "قل" in result or "اعوذ" in result or "الناس" in result, f"Result should contain key words from An-Nas, got: {result}"

    words = result.split()
    assert len(words) >= 2, f"Result should have at least 2 words, got {len(words)}"

    print("✓ PASSED: An-Nas test")
    return True


def main():
    """Run all tests"""
    print("="*80)
    print("Quran Seq2Seq Model - Specific Input Tests (No Padding)")
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
    total = 5

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

    try:
        if test_an_nas(model, word_to_idx, idx_to_word, device):
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
