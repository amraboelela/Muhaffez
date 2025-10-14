import json
import torch
import torch.nn.functional as F
from model import QuranMatcherModel, load_quran_data, load_vocabulary

class QuranPredictor:
    def __init__(self, model_path, vocab_path, quran_path):
        # Load vocabulary
        self.vocabulary, self.vocab_size = load_vocabulary(vocab_path)
        
        # Load ayat
        self.ayat = load_quran_data(quran_path)
        
        # Load model
        checkpoint = torch.load(model_path, map_location=torch.device('cpu'))
        self.model = QuranMatcherModel(
            vocab_size=checkpoint['vocab_size'],
            output_size=checkpoint['output_size']
        )
        self.model.load_state_dict(checkpoint['model_state_dict'])
        self.model.eval()
        
        print(f"Model loaded successfully\!")
        print(f"Vocabulary size: {self.vocab_size}")
        print(f"Total ayat: {len(self.ayat)}")
    
    def tokenize(self, text, max_length=100):
        """Convert text to token indices"""
        tokens = []
        pad_token = self.vocabulary.get('<PAD>', 0)
        unk_token = self.vocabulary.get('<UNK>', 1)
        
        for char in text:
            token = self.vocabulary.get(char, unk_token)
            tokens.append(token)
        
        # Pad or truncate to max_length
        if len(tokens) < max_length:
            tokens.extend([pad_token] * (max_length - len(tokens)))
        else:
            tokens = tokens[:max_length]
        
        return tokens
    
    def predict(self, partial_ayah, top_k=5):
        """Predict the most likely ayah for the given partial text"""
        # Tokenize input
        tokens = self.tokenize(partial_ayah)
        x = torch.tensor([tokens], dtype=torch.long)
        
        # Get predictions
        with torch.no_grad():
            output = self.model(x)
            probabilities = F.softmax(output, dim=1)[0]
        
        # Get top-k predictions
        top_probs, top_indices = torch.topk(probabilities, top_k)
        
        results = []
        for prob, idx in zip(top_probs, top_indices):
            results.append({
                'index': idx.item(),
                'probability': prob.item(),
                'ayah': self.ayat[idx.item()]
            })
        
        return results
    
    def get_full_output(self, partial_ayah):
        """Get full probability distribution for all ayat"""
        tokens = self.tokenize(partial_ayah)
        x = torch.tensor([tokens], dtype=torch.long)
        
        with torch.no_grad():
            output = self.model(x)
            probabilities = F.softmax(output, dim=1)[0]
        
        return probabilities.numpy()

def main():
    # Initialize predictor
    predictor = QuranPredictor(
        model_path='quran_matcher_model.pth',
        vocab_path='vocabulary.json',
        quran_path='../Muhaffez/quran-simple-min.txt'
    )
    
    # Test with sample inputs
    test_inputs = [
        'بسم الله',
        'الحمد لله',
        'قل هو الله',
        'الله لا اله الا هو',
    ]
    
    print("\n" + "="*60)
    print("Testing Quran Ayah Predictor")
    print("="*60)
    
    for test_input in test_inputs:
        print(f"\nInput: {test_input}")
        print("-" * 60)
        results = predictor.predict(test_input, top_k=3)
        
        for i, result in enumerate(results, 1):
            print(f"{i}. [Index: {result['index']}, Prob: {result['probability']:.4f}]")
            print(f"   {result['ayah']}")
    
    print("\n" + "="*60)
    print("\nInteractive mode - Enter partial ayah text (or 'quit' to exit):")
    print("="*60)
    
    while True:
        user_input = input("\nEnter partial ayah: ").strip()
        if user_input.lower() in ['quit', 'exit', 'q']:
            break
        
        if not user_input:
            continue
        
        results = predictor.predict(user_input, top_k=3)
        print("\nTop 3 predictions:")
        print("-" * 60)
        for i, result in enumerate(results, 1):
            print(f"{i}. [Index: {result['index']}, Prob: {result['probability']:.4f}]")
            print(f"   {result['ayah']}")

if __name__ == '__main__':
    main()
