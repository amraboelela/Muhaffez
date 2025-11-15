# Quran Ayah Matcher AI Model

This directory contains a neural network model for matching partial Quran ayat (with potential mistakes) to the correct ayah.

## Model Architecture

- **Input**: 100 nodes (tokenized characters using vocabulary.json)
- **Hidden Layers**: 256 nodes with ReLU activation and dropout
- **Output**: 6203 nodes (one for each ayah in the Quran)

The model uses:
- Embedding layer to convert character tokens to dense vectors
- Fully connected layers with dropout for regularization
- Softmax output to get probability distribution over all ayat

## Files

- `vocabulary.json`: Character-to-token mapping for Arabic text (47 unique characters)
- `model.py`: PyTorch model architecture and dataset classes
- `train.py`: Training script with noise augmentation
- `predict.py`: Inference script for testing the model

## Setup

Install dependencies:
```bash
pip install torch numpy
```

## Training

The training script adds noise to ayat to simulate mistakes (missing characters, partial text):

```bash
cd ai
python train.py
```

This will:
- Load the Quran text (6203 ayat)
- Create a dataset with noisy/partial inputs
- Train for 20 epochs
- Save the model to `quran_matcher_model.pth`

## Inference

Test the trained model:

```bash
cd ai
python predict.py
```

This will:
- Load the trained model
- Run some test predictions
- Enter interactive mode for custom inputs

### Example Usage

```python
from predict import QuranPredictor

predictor = QuranPredictor(
    model_path='quran_matcher_model.pth',
    vocab_path='vocabulary.json',
    quran_path='../Muhaffez/quran-simple-min.txt'
)

# Get top 3 predictions
results = predictor.predict('بسم الله', top_k=3)

# Get full probability distribution
probabilities = predictor.get_full_output('بسم الله')
```

## How It Works

1. **Tokenization**: Each character in the input is converted to a token ID using `vocabulary.json`
2. **Padding**: Input is padded or truncated to exactly 100 tokens
3. **Embedding**: Tokens are embedded into 64-dimensional vectors
4. **Neural Network**: Processes the embedded sequence through hidden layers
5. **Output**: Softmax over 6203 nodes gives probability for each ayah
6. **Result**: The ayah with probability closest to 1.0 is the predicted match

## Model Details

- Total parameters: ~1.6M
- Training augmentation: 20% noise (character removal or partial text)
- Optimizer: Adam (lr=0.001)
- Loss: Cross-Entropy
- Batch size: 32
