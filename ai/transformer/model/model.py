import json
import math
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset

class PositionalEncoding(nn.Module):
    """Positional encoding for transformer using sinusoidal functions"""
    def __init__(self, d_model, max_len=100):
        super(PositionalEncoding, self).__init__()

        # Create positional encoding matrix
        pe = torch.zeros(max_len, d_model)
        position = torch.arange(0, max_len, dtype=torch.float).unsqueeze(1)
        div_term = torch.exp(torch.arange(0, d_model, 2).float() * (-math.log(10000.0) / d_model))

        pe[:, 0::2] = torch.sin(position * div_term)
        pe[:, 1::2] = torch.cos(position * div_term)

        pe = pe.unsqueeze(0)  # Add batch dimension
        self.register_buffer('pe', pe)

    def forward(self, x):
        """Add positional encoding to input embeddings"""
        # x shape: (batch_size, seq_len, d_model)
        return x + self.pe[:, :x.size(1), :]


class TransformerBlock(nn.Module):
    """Single transformer decoder block with self-attention and feed-forward"""
    def __init__(self, d_model, n_heads, d_ff, dropout=0.1):
        super(TransformerBlock, self).__init__()

        # Multi-head self-attention
        self.self_attn = nn.MultiheadAttention(d_model, n_heads, dropout=dropout, batch_first=True)

        # Feed-forward network
        self.ff = nn.Sequential(
            nn.Linear(d_model, d_ff),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(d_ff, d_model)
        )

        # Layer normalization
        self.norm1 = nn.LayerNorm(d_model)
        self.norm2 = nn.LayerNorm(d_model)

        # Dropout
        self.dropout = nn.Dropout(dropout)

    def forward(self, x, attn_mask=None):
        """
        Forward pass through transformer block
        x shape: (batch_size, seq_len, d_model)
        """
        # Self-attention with residual connection
        attn_output, _ = self.self_attn(x, x, x, attn_mask=attn_mask)
        x = self.norm1(x + self.dropout(attn_output))

        # Feed-forward with residual connection
        ff_output = self.ff(x)
        x = self.norm2(x + self.dropout(ff_output))

        return x


class QuranTransformerModel(nn.Module):
    """Decoder-only transformer model for Quran ayah classification"""
    def __init__(self, vocab_size, max_length=60, d_model=128, n_heads=8, n_layers=4, d_ff=512, output_size=6203, dropout=0.1):
        super(QuranTransformerModel, self).__init__()

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

        # Classification head
        self.fc = nn.Linear(d_model, output_size)

        # Initialize weights
        self._init_weights()

    def _init_weights(self):
        """Initialize weights using Xavier/Glorot initialization"""
        for p in self.parameters():
            if p.dim() > 1:
                nn.init.xavier_uniform_(p)

    def forward(self, x, attn_mask=None):
        """
        Forward pass
        x shape: (batch_size, seq_len)
        Returns: (batch_size, output_size)
        """
        # Embed tokens
        x = self.embedding(x)  # (batch_size, seq_len, d_model)
        x = x * math.sqrt(self.d_model)  # Scale embeddings

        # Add positional encoding
        x = self.pos_encoding(x)
        x = self.dropout(x)

        # Pass through transformer blocks
        for transformer_block in self.transformer_blocks:
            x = transformer_block(x, attn_mask)

        # Global average pooling over sequence dimension
        x = torch.mean(x, dim=1)  # (batch_size, d_model)

        # Classification head
        x = self.fc(x)  # (batch_size, output_size)

        return x


class QuranAyahDataset(Dataset):
    """Dataset for Quran ayah text with tokenization"""
    def __init__(self, ayat_list, vocabulary, max_length=60):
        self.ayat = ayat_list
        self.vocabulary = vocabulary
        self.max_length = max_length
        self.pad_token = vocabulary.get('<PAD>', 0)
        self.unk_token = vocabulary.get('<UNK>', 1)

    def __len__(self):
        return len(self.ayat)

    def tokenize(self, text):
        """Convert text to token indices"""
        tokens = []
        for char in text:
            token = self.vocabulary.get(char, self.unk_token)
            tokens.append(token)

        # Pad or truncate to max_length
        if len(tokens) < self.max_length:
            tokens.extend([self.pad_token] * (self.max_length - len(tokens)))
        else:
            tokens = tokens[:self.max_length]

        return tokens

    def __getitem__(self, idx):
        ayah = self.ayat[idx]
        tokens = self.tokenize(ayah)

        # Input: tokenized ayah
        x = torch.tensor(tokens, dtype=torch.long)
        # Output: ayah index
        y = torch.tensor(idx, dtype=torch.long)

        return x, y


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


def load_vocabulary(vocab_path):
    """Load vocabulary from JSON file"""
    with open(vocab_path, 'r', encoding='utf-8') as f:
        vocab_data = json.load(f)

    return vocab_data['char_to_token'], vocab_data['vocab_size']


if __name__ == "__main__":
    # Test the model architecture
    print("Testing QuranTransformerModel architecture...")

    # Load vocabulary
    vocabulary, vocab_size = load_vocabulary('vocabulary_normalized.json')
    print(f"Vocabulary size: {vocab_size}")

    # Load Quran data
    ayat = load_quran_data('../../Muhaffez/quran-simple-min.txt')
    print(f"Total ayat: {len(ayat)}")

    # Create model
    model = QuranTransformerModel(
        vocab_size=vocab_size,
        max_length=60,
        d_model=128,
        n_heads=8,
        n_layers=4,
        d_ff=512,
        output_size=len(ayat),
        dropout=0.1
    )
    print(f"\nModel architecture:")
    print(model)

    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"\nTotal parameters: {total_params:,}")
    print(f"Trainable parameters: {trainable_params:,}")

    # Test with a sample
    dataset = QuranAyahDataset(ayat, vocabulary, max_length=60)
    sample_x, sample_y = dataset[0]
    print(f"\nSample input shape: {sample_x.shape}")
    print(f"Sample output label: {sample_y}")

    # Test forward pass
    sample_x = sample_x.unsqueeze(0)  # Add batch dimension
    output = model(sample_x)
    print(f"Model output shape: {output.shape}")
    print(f"Expected: (1, {len(ayat)})")
