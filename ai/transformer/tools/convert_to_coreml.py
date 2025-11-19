#!/usr/bin/env python3
"""
Convert the trained Quran Seq2Seq transformer model to CoreML format
"""
import torch
import coremltools as ct
import sys
import os

# Add parent directories to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))

from seq2seq_model import QuranSeq2SeqModel, load_vocabulary


class QuranSeq2SeqWrapper(torch.nn.Module):
    """Wrapper for CoreML export - takes input tokens and returns output logits"""
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, input_ids, attention_mask):
        """
        Args:
            input_ids: (batch_size, seq_len) - Token IDs
            attention_mask: (batch_size, seq_len) - Attention mask (1=real token, 0=padding)

        Returns:
            logits: (batch_size, seq_len, vocab_size) - Output logits
        """
        return self.model(input_ids, attention_mask)


def convert_model_to_coreml(pytorch_model_path, vocab_path, output_path):
    """Convert PyTorch model to CoreML"""

    print(f"Loading vocabulary from {vocab_path}...")
    word_to_idx, idx_to_word, vocab_size = load_vocabulary(vocab_path)
    print(f"Vocabulary size: {vocab_size}")

    print(f"\nLoading PyTorch model from {pytorch_model_path}...")

    # Create model with same architecture as training
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
    checkpoint = torch.load(pytorch_model_path, map_location='cpu')

    # Handle both old and new checkpoint formats
    if 'model' in checkpoint:
        model.load_state_dict(checkpoint['model'])
    elif 'model_state_dict' in checkpoint:
        model.load_state_dict(checkpoint['model_state_dict'])
    else:
        model.load_state_dict(checkpoint)

    model.eval()

    print(f"Model loaded successfully!")
    print(f"  Epoch: {checkpoint.get('epoch', 'N/A')}")
    print(f"  Accuracy: {checkpoint.get('accuracy', 'N/A')}")
    print(f"  Loss: {checkpoint.get('loss', 'N/A')}")

    # Wrap model for export
    wrapped_model = QuranSeq2SeqWrapper(model)
    wrapped_model.eval()

    # Create example inputs for tracing
    max_length = 50
    batch_size = 1

    example_input_ids = torch.randint(0, vocab_size, (batch_size, max_length), dtype=torch.long)
    example_attention_mask = torch.ones((batch_size, max_length), dtype=torch.long)

    print(f"\nTracing model with example inputs...")
    print(f"  Input IDs shape: {example_input_ids.shape}")
    print(f"  Attention mask shape: {example_attention_mask.shape}")

    # Trace the model
    traced_model = torch.jit.trace(
        wrapped_model,
        (example_input_ids, example_attention_mask)
    )

    print(f"\nConverting to CoreML...")

    # Convert to CoreML with flexible input shapes (3-50 sequence length)
    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(
                name="input_ids",
                shape=ct.Shape(shape=(1, ct.RangeDim(3, 50))),
                dtype=int
            ),
            ct.TensorType(
                name="attention_mask",
                shape=ct.Shape(shape=(1, ct.RangeDim(3, 50))),
                dtype=int
            )
        ],
        outputs=[
            ct.TensorType(
                name="logits",
                dtype=float
            )
        ],
        minimum_deployment_target=ct.target.iOS15,
        compute_units=ct.ComputeUnit.ALL
    )

    # Add metadata
    mlmodel.author = "Amr Aboelela"
    mlmodel.short_description = "Quran Seq2Seq Transformer Model"
    mlmodel.version = "1.0"

    # Add input descriptions
    mlmodel.input_description["input_ids"] = "Token IDs for the input sequence"
    mlmodel.input_description["attention_mask"] = "Attention mask (1=real token, 0=padding)"

    # Add output description
    mlmodel.output_description["logits"] = "Output logits (batch_size, seq_len, vocab_size)"

    # Save the model
    print(f"\nSaving CoreML model to {output_path}...")
    mlmodel.save(output_path)

    print(f"\n✓ Conversion completed successfully!")
    print(f"  Output: {output_path}")
    print(f"  Model size: {os.path.getsize(output_path) / (1024*1024):.2f} MB")


def main():
    # Paths
    pytorch_model_path = '../model/quran_seq2seq_model.pt'
    vocab_path = '../model/vocabulary.json'
    output_path = '../../../Muhaffez/QuranSeq2Seq.mlpackage'

    if not os.path.exists(pytorch_model_path):
        print(f"Error: PyTorch model not found at {pytorch_model_path}")
        print("Please train the model first using train.sh")
        return

    if not os.path.exists(vocab_path):
        print(f"Error: Vocabulary file not found at {vocab_path}")
        return

    convert_model_to_coreml(pytorch_model_path, vocab_path, output_path)


if __name__ == '__main__':
    main()
