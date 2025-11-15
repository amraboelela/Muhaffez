import json
import math
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset

class PositionalEncoding(nn.Module):
    """Learned positional encoding for transformer (like GPT/ChatGPT)"""
    def __init__(self, d_model, max_len=200):
        super(PositionalEncoding, self).__init__()
        # Learned positional embeddings
        self.pos_embedding = nn.Embedding(max_len, d_model)

    def forward(self, x):
        """Add positional encoding to input embeddings"""
        # x shape: (batch_size, seq_len, d_model)
        batch_size, seq_len, d_model = x.shape

        # Create position indices [0, 1, 2, ..., seq_len-1]
        positions = torch.arange(0, seq_len, device=x.device).unsqueeze(0)  # (1, seq_len)

        # Look up positional embeddings
        pos_encodings = self.pos_embedding(positions)  # (1, seq_len, d_model)

        # Add to input embeddings
        return x + pos_encodings


class TransformerBlock(nn.Module):
    """Single transformer decoder block with causal self-attention"""
    def __init__(self, d_model, n_heads, d_ff, dropout=0.1):
        super(TransformerBlock, self).__init__()

        # Multi-head causal self-attention
        self.self_attn = nn.MultiheadAttention(d_model, n_heads, dropout=dropout, batch_first=True)

        # Feed-forward network
        self.ff = nn.Sequential(
            nn.Linear(d_model, d_ff),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(d_ff, d_model)
        )

        # Layer normalization
        self.norm1 = nn.LayerNorm(d_model)
        self.norm2 = nn.LayerNorm(d_model)

        # Dropout
        self.dropout = nn.Dropout(dropout)

    def forward(self, x, causal_mask=None):
        """
        Forward pass through transformer block
        x shape: (batch_size, seq_len, d_model)
        """
        # Self-attention with causal mask and residual connection
        attn_output, _ = self.self_attn(x, x, x, attn_mask=causal_mask)
        x = self.norm1(x + self.dropout(attn_output))

        # Feed-forward with residual connection
        ff_output = self.ff(x)
        x = self.norm2(x + self.dropout(ff_output))

        return x


class QuranSeq2SeqModel(nn.Module):
    """Decoder-only transformer for sequence-to-sequence generation"""
    def __init__(self, vocab_size, max_length=50, d_model=128, n_heads=4, n_layers=4, d_ff=512, dropout=0.1):
        super(QuranSeq2SeqModel, self).__init__()

        self.vocab_size = vocab_size
        self.max_length = max_length
        self.d_model = d_model

        # Token embedding
        self.embedding = nn.Embedding(vocab_size, d_model)

        # Positional encoding
        self.pos_encoding = PositionalEncoding(d_model, max_len=max_length)

        # Transformer blocks
        self.transformer_blocks = nn.ModuleList([
            TransformerBlock(d_model, n_heads, d_ff, dropout)
            for _ in range(n_layers)
        ])

        # Dropout after embedding
        self.dropout = nn.Dropout(dropout)

        # Output head (vocabulary prediction)
        self.output_head = nn.Linear(d_model, vocab_size)

        # Initialize weights
        self._init_weights()

    def _init_weights(self):
        """Initialize weights using Xavier/Glorot initialization"""
        for p in self.parameters():
            if p.dim() > 1:
                nn.init.xavier_uniform_(p)

    def generate_causal_mask(self, seq_len):
        """Generate causal mask to prevent attending to future tokens"""
        mask = torch.triu(torch.ones(seq_len, seq_len), diagonal=1)
        mask = mask.masked_fill(mask == 1, float('-inf'))
        return mask

    def forward(self, x, attention_mask=None):
        """
        Forward pass
        x shape: (batch_size, seq_len)
        attention_mask: (batch_size, seq_len) - 1 for real tokens, 0 for padding
        Returns: (batch_size, seq_len, vocab_size)
        """
        batch_size, seq_len = x.shape

        # Embed tokens
        x = self.embedding(x)  # (batch_size, seq_len, d_model)
        x = x * math.sqrt(self.d_model)  # Scale embeddings

        # Add positional encoding
        x = self.pos_encoding(x)
        x = self.dropout(x)

        # Create causal mask (seq_len, seq_len)
        causal_mask = self.generate_causal_mask(seq_len).to(x.device)

        # Pass through transformer blocks
        for transformer_block in self.transformer_blocks:
            x = transformer_block(x, causal_mask)

        # Output head
        logits = self.output_head(x)  # (batch_size, seq_len, vocab_size)

        return logits


def load_vocabulary(vocab_path):
    """Load vocabulary from JSON array file"""
    with open(vocab_path, 'r', encoding='utf-8') as f:
        vocab_array = json.load(f)

    # Build word-to-index mapping
    word_to_idx = {word: idx for idx, word in enumerate(vocab_array)}
    idx_to_word = {idx: word for idx, word in enumerate(vocab_array)}

    return word_to_idx, idx_to_word, len(vocab_array)


def load_quran_data(quran_path):
    """Load Quran text and filter out empty lines and markers"""
    with open(quran_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    ayat = []
    for line in lines:
        line = line.strip()
        if line and line != '-' and line != '*':
            ayat.append(line)

    return ayat


if __name__ == "__main__":
    # Test the model architecture
    print("Testing QuranSeq2SeqModel architecture...")

    # Load vocabulary
    word_to_idx, idx_to_word, vocab_size = load_vocabulary('vocabulary.json')
    print(f"Vocabulary size: {vocab_size}")

    # Create model
    model = QuranSeq2SeqModel(
        vocab_size=vocab_size,
        max_length=50,
        d_model=256,
        n_heads=8,
        n_layers=6,
        d_ff=1024,
        dropout=0.1
    )
    print(f"\nModel architecture:")
    print(model)

    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"\nTotal parameters: {total_params:,}")
    print(f"Trainable parameters: {trainable_params:,}")

    # Test with a sample sequence
    sample_input = torch.randint(0, vocab_size, (2, 20))  # Batch of 2, seq_len 20
    print(f"\nSample input shape: {sample_input.shape}")

    # Test forward pass
    output = model(sample_input)
    print(f"Model output shape: {output.shape}")
    print(f"Expected: (2, 20, {vocab_size})")
