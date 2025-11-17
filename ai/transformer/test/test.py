#!/usr/bin/env python3
"""
Test the trained Quran Seq2Seq model with different input/output combinations
"""
import torch
import sys
import os
import random
import shutil

# Add parent directories to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))

from seq2seq_model import QuranSeq2SeqModel, load_vocabulary, load_quran_data


def log_print(message, log_file=None, log_only=False):
    """Print to console and log file

    Args:
        message: Message to print/log
        log_file: Path to log file
        log_only: If True, only write to log file (not console)
    """
    if not log_only:
        print(message)
    if log_file:
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(message + '\n')


def test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words, test_count=100, log_file=None, skip_position=None, replace_position=None, vocab_words=None):
    """Test model with specific number of input words

    Args:
        skip_position: If set, skip this word position (0-indexed)
        replace_position: If set, replace this word position with random wrong word (0-indexed)
        vocab_words: List of vocabulary words for replacement
    """

    bos_token = word_to_idx['<s>']
    eos_token = word_to_idx['</s>']
    reader_token = word_to_idx['القاريء:']
    ayah_token = word_to_idx['الاية:']

    correct = 0
    total = 0
    failed_samples = []  # Track failed samples

    # Filter ayat with at least 6 words
    valid_indices = [i for i, ayah in enumerate(ayat) if len(ayah.split()) >= 6]

    # Randomly select from valid ayat only
    test_indices = random.sample(valid_indices, min(test_count, len(valid_indices)))

    for idx in test_indices:
        ayah = ayat[idx]
        words = ayah.split()

        # Get input words based on variant type
        if skip_position is not None:
            # Skip variant (similar to dataset generation)
            if len(words) <= 3:
                input_words = words[:min(len(words), num_input_words)]
            else:
                # Take words before skip position
                before_skip = words[0:skip_position]
                # Calculate how many more words we need
                remaining = num_input_words - len(before_skip)
                # Take words after skip position
                after_skip = words[skip_position+1:min(len(words), skip_position+1+remaining)]
                input_words = before_skip + after_skip
        elif replace_position is not None and vocab_words:
            # Replace word at position variant
            if len(words) <= 3:
                input_words = words[:min(len(words), num_input_words)]
            else:
                input_words = words[:min(len(words), num_input_words)].copy()
                # Replace word at position with random wrong word
                if replace_position < len(input_words):
                    original_word = input_words[replace_position]
                    replacement_word = random.choice(vocab_words)
                    while replacement_word == original_word and len(vocab_words) > 1:
                        replacement_word = random.choice(vocab_words)
                    input_words[replace_position] = replacement_word
        else:
            # Regular variant
            input_words = words[:min(num_input_words, len(words))]

        expected_output_words = words[:min(6, len(words))]

        # Build sequence: <s> القاريء: [input_words] الاية: [expected_output] </s>
        sequence_tokens = [bos_token, reader_token]
        for word in input_words:
            if word in word_to_idx:
                token = word_to_idx[word]
                sequence_tokens.append(token)
        sequence_tokens.append(ayah_token)

        expected_output_tokens = []
        for word in expected_output_words:
            if word in word_to_idx:
                token = word_to_idx[word]
                expected_output_tokens.append(token)

        sequence_tokens.extend(expected_output_tokens)
        sequence_tokens.append(eos_token)

        # Convert to tensor
        input_tensor = torch.tensor([sequence_tokens], dtype=torch.long).to(device)
        attention_mask = torch.ones_like(input_tensor).to(device)

        # Get model predictions
        with torch.no_grad():
            logits = model(input_tensor, attention_mask=attention_mask)
            predictions = torch.argmax(logits, dim=-1)

            # Get top-5 predictions for each position (for analysis)
            top_k = 5
            top_k_logits = torch.topk(logits[0], k=top_k, dim=-1)
            top_k_indices = top_k_logits.indices.cpu().tolist()
            top_k_probs = torch.softmax(logits[0], dim=-1)
            top_k_prob_values = torch.gather(top_k_probs, 1, top_k_logits.indices).cpu().tolist()

        # Find where الاية: is
        ayah_pos = sequence_tokens.index(ayah_token)

        # Get predicted tokens (after الاية:, before </s>)
        predicted_tokens = predictions[0, ayah_pos:ayah_pos + len(expected_output_tokens)].cpu().tolist()

        # Check if prediction matches expected output
        if predicted_tokens == expected_output_tokens:
            correct += 1
        else:
            # Track failed sample with top-k alternatives
            predicted_words = [idx_to_word.get(t, '?') for t in predicted_tokens]
            match_count = sum(1 for p, e in zip(predicted_tokens, expected_output_tokens) if p == e)

            # Get top-k alternatives for mismatched positions
            alternatives = []
            for i, (pred_token, exp_token) in enumerate(zip(predicted_tokens, expected_output_tokens)):
                pos = ayah_pos + i
                if pred_token != exp_token:
                    # Get top-k words and probabilities for this position
                    top_words = [idx_to_word.get(idx, '?') for idx in top_k_indices[pos]]
                    top_probs = top_k_prob_values[pos]

                    # Check if expected token is in top-k
                    expected_rank = None
                    if exp_token in top_k_indices[pos]:
                        expected_rank = top_k_indices[pos].index(exp_token) + 1

                    alternatives.append({
                        'position': i,
                        'expected_word': idx_to_word.get(exp_token, '?'),
                        'predicted_word': idx_to_word.get(pred_token, '?'),
                        'top_k_words': top_words,
                        'top_k_probs': top_probs,
                        'expected_rank': expected_rank
                    })

            failed_samples.append({
                'input': input_words,
                'expected': expected_output_words,
                'predicted': predicted_words,
                'match_count': match_count,
                'total_words': len(expected_output_tokens),
                'ayah_index': idx + 1,
                'alternatives': alternatives
            })

        total += 1

        # Show first few examples (log only, not console)
        if total <= 3:
            predicted_words = [idx_to_word.get(t, '?') for t in predicted_tokens]
            log_print(f'  Example {total}:', log_file, log_only=True)
            log_print(f'    Input: {" ".join(input_words)}', log_file, log_only=True)
            log_print(f'    Expected: {" ".join(expected_output_words)}', log_file, log_only=True)
            log_print(f'    Predicted: {" ".join(predicted_words)}', log_file, log_only=True)
            match_count = sum(1 for p, e in zip(predicted_tokens, expected_output_tokens) if p == e)
            log_print(f'    Match: {match_count}/{len(expected_output_tokens)} words', log_file, log_only=True)
            log_print('', log_file, log_only=True)

    # Print failed samples at the end
    if failed_samples:
        log_print(f'  Failed samples ({len(failed_samples)} total):', log_file, log_only=True)
        log_print('  ' + '-' * 60, log_file, log_only=True)
        for i, sample in enumerate(failed_samples, 1):
            log_print(f'  Failed {i} (Ayah {sample["ayah_index"]}):', log_file, log_only=True)
            log_print(f'    Input: {" ".join(sample["input"])}', log_file, log_only=True)
            log_print(f'    Expected: {" ".join(sample["expected"])}', log_file, log_only=True)
            log_print(f'    Predicted: {" ".join(sample["predicted"])}', log_file, log_only=True)
            log_print(f'    Match: {sample["match_count"]}/{sample["total_words"]} words', log_file, log_only=True)

            # Show top-k alternatives for mismatched positions
            if sample.get('alternatives'):
                log_print(f'    Mismatched positions:', log_file, log_only=True)
                for alt in sample['alternatives']:
                    pos = alt['position']
                    expected = alt['expected_word']
                    predicted = alt['predicted_word']
                    rank_info = f" (expected rank: #{alt['expected_rank']})" if alt['expected_rank'] else " (expected NOT in top-5)"

                    log_print(f'      Position {pos}: expected="{expected}", predicted="{predicted}"{rank_info}', log_file, log_only=True)
                    log_print(f'        Top-5 alternatives:', log_file, log_only=True)
                    for j, (word, prob) in enumerate(zip(alt['top_k_words'], alt['top_k_probs']), 1):
                        marker = " ✓" if word == expected else ""
                        log_print(f'          {j}. {word} ({prob:.3f}){marker}', log_file, log_only=True)

            log_print('', log_file, log_only=True)

    accuracy = 100 * correct / total if total > 0 else 0
    return accuracy, total


def test_model(model_path, vocab_path, quran_path, log_file=None):
    """Test the trained model"""

    # Backup existing log file and clear it (log only)
    if log_file and os.path.exists(log_file):
        backup_file = log_file.replace('.txt', '_backup.txt')
        shutil.copy2(log_file, backup_file)
        # Clear the log file after backup
        with open(log_file, 'w', encoding='utf-8') as f:
            f.write('')
        log_print(f'✓ Log backup created: {backup_file}', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Load vocabulary
    word_to_idx, idx_to_word, vocab_size = load_vocabulary(vocab_path)
    log_print(f'Vocabulary size: {vocab_size}', log_file)
    log_print('', log_file)

    # Set device
    if torch.backends.mps.is_available():
        device = torch.device('mps')
        log_print('🚀 Using Metal GPU (Apple Silicon)', log_file)
    elif torch.cuda.is_available():
        device = torch.device('cuda')
        log_print('🚀 Using CUDA GPU', log_file)
    else:
        device = torch.device('cpu')
        log_print('Using CPU', log_file)
    log_print(f'Device: {device}', log_file)
    log_print('', log_file)

    # Create model (same architecture as training)
    model = QuranSeq2SeqModel(
        vocab_size=vocab_size,
        max_length=50,
        d_model=128,
        n_heads=4,
        n_layers=4,
        d_ff=512,
        dropout=0.1
    )

    # Load checkpoint
    checkpoint = torch.load(model_path, map_location=device)

    # Handle both old and new checkpoint formats
    if 'model' in checkpoint:
        model.load_state_dict(checkpoint['model'])
    elif 'model_state_dict' in checkpoint:
        model.load_state_dict(checkpoint['model_state_dict'])
    else:
        model.load_state_dict(checkpoint)

    model = model.to(device)
    model.eval()

    epoch_num = checkpoint.get('epoch', -1) + 1 if 'epoch' in checkpoint else 'N/A'
    accuracy_val = f"{checkpoint.get('accuracy', 0):.1f}%" if 'accuracy' in checkpoint else 'N/A'
    loss_val = f"{checkpoint.get('loss', 0):.4f}" if 'loss' in checkpoint else 'N/A'

    log_print(f'✓ Model loaded from {model_path}', log_file)
    log_print(f'  Epoch: {epoch_num}', log_file)
    log_print(f'  Training Accuracy: {accuracy_val}', log_file)
    log_print(f'  Training Loss: {loss_val}', log_file)
    log_print('', log_file)

    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    log_print(f'Total parameters: {total_params:,}', log_file)
    log_print('', log_file)

    # Load Android normalized Quran data
    ayat = load_quran_data(quran_path)
    log_print(f'Total ayat: {len(ayat)}', log_file)
    log_print('', log_file)

    # Get vocabulary words for replacement tests
    vocab_words = [word for word in word_to_idx.keys() if word not in ['<s>', '</s>', 'القاريء:', 'الاية:']]

    # Test with different input lengths and variants
    log_print('=' * 60, log_file, log_only=True)
    log_print('TESTING WITH DIFFERENT INPUT WORD COUNTS AND VARIANTS', log_file, log_only=True)
    log_print('=' * 60, log_file, log_only=True)
    log_print('', log_file, log_only=True)

    results = {}

    # Test regular (no skip, no replace) for 3-6 input words
    for num_input_words in range(3, 7):
        test_name = f'{num_input_words} words'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words, test_count=100, log_file=log_file)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test skip first word (for 4-6 input words)
    for num_input_words in range(4, 7):
        test_name = f'{num_input_words} words (skip 1st)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words - 1, test_count=100, log_file=log_file, skip_position=0)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test skip second word (for 4-6 input words)
    for num_input_words in range(4, 7):
        test_name = f'{num_input_words} words (skip 2nd)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words - 1, test_count=100, log_file=log_file, skip_position=1)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test skip third word (for 4-6 input words)
    for num_input_words in range(4, 7):
        test_name = f'{num_input_words} words (skip 3rd)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words - 1, test_count=100, log_file=log_file, skip_position=2)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test skip fourth word (for 5-6 input words)
    for num_input_words in range(5, 7):
        test_name = f'{num_input_words} words (skip 4th)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words - 1, test_count=100, log_file=log_file, skip_position=3)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test skip fifth word (only for 6 input words)
    for num_input_words in range(6, 7):
        test_name = f'{num_input_words} words (skip 5th)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words - 1, test_count=100, log_file=log_file, skip_position=4)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test replace first word (for 4-6 input words)
    for num_input_words in range(4, 7):
        test_name = f'{num_input_words} words (wrong 1st)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words, test_count=100, log_file=log_file, replace_position=0, vocab_words=vocab_words)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test replace second word (for 4-6 input words)
    for num_input_words in range(4, 7):
        test_name = f'{num_input_words} words (wrong 2nd)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words, test_count=100, log_file=log_file, replace_position=1, vocab_words=vocab_words)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test replace third word (for 4-6 input words)
    for num_input_words in range(4, 7):
        test_name = f'{num_input_words} words (wrong 3rd)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words, test_count=100, log_file=log_file, replace_position=2, vocab_words=vocab_words)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test replace fourth word (for 5-6 input words)
    for num_input_words in range(5, 7):
        test_name = f'{num_input_words} words (wrong 4th)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words, test_count=100, log_file=log_file, replace_position=3, vocab_words=vocab_words)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Test replace fifth word (only for 6 input words)
    for num_input_words in range(6, 7):
        test_name = f'{num_input_words} words (wrong 5th)'
        log_print(f'Testing {test_name} → 6 output words:', log_file, log_only=True)
        log_print('-' * 60, log_file, log_only=True)
        accuracy, total = test_model_with_inputs(model, word_to_idx, idx_to_word, ayat, device, num_input_words, test_count=100, log_file=log_file, replace_position=4, vocab_words=vocab_words)
        results[test_name] = accuracy
        log_print(f'Accuracy: {accuracy:.1f}% ({total} samples tested)', log_file, log_only=True)
        log_print('', log_file, log_only=True)

    # Summary
    log_print('=' * 60, log_file)
    log_print('SUMMARY', log_file)
    log_print('=' * 60, log_file)

    # Group results by category
    regular_results = {k: v for k, v in results.items() if 'skip' not in k and 'wrong' not in k}
    skip_results = {k: v for k, v in results.items() if 'skip' in k}
    wrong_results = {k: v for k, v in results.items() if 'wrong' in k}

    # Display regular results
    log_print('Regular (no skip, no wrong):', log_file)
    for test_name, accuracy in regular_results.items():
        log_print(f'  {test_name}: {accuracy:.1f}%', log_file)

    # Display skip results
    if skip_results:
        log_print('', log_file)
        log_print('Skip variants:', log_file)
        for test_name, accuracy in skip_results.items():
            log_print(f'  {test_name}: {accuracy:.1f}%', log_file)

    # Display wrong word results
    if wrong_results:
        log_print('', log_file)
        log_print('Wrong first word:', log_file)
        for test_name, accuracy in wrong_results.items():
            log_print(f'  {test_name}: {accuracy:.1f}%', log_file)

    # Overall accuracy
    if results:
        overall_accuracy = sum(results.values()) / len(results)
        log_print('', log_file)
        log_print(f'Overall accuracy: {overall_accuracy:.1f}% (across {len(results)} tests)', log_file)
    log_print('', log_file)


def main():
    log_file = 'log.txt'

    model_path = '../model/quran_seq2seq_model.pt'
    vocab_path = '../model/vocabulary.json'
    quran_path = '/Users/amraboelela/develop/android/AndroidArabicWhisper/muhaffez-whisper/datasets/quran-simple-norm.txt'

    if not os.path.exists(model_path):
        log_print(f'Error: Model file not found at {model_path}', log_file)
        log_print('Please train the model first using train.sh', log_file)
        return

    if not os.path.exists(vocab_path):
        log_print(f'Error: Vocabulary file not found at {vocab_path}', log_file)
        return

    if not os.path.exists(quran_path):
        log_print(f'Error: Quran file not found at {quran_path}', log_file)
        return

    test_model(model_path, vocab_path, quran_path, log_file)


if __name__ == '__main__':
    main()
