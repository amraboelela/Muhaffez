import torch
import coremltools as ct
from model import QuranMatcherModel, load_vocabulary
import json

def convert_to_coreml():
    """Convert the PyTorch model to CoreML format"""

    # Load vocabulary to get vocab size
    vocabulary, vocab_size = load_vocabulary('vocabulary_normalized.json')
    print(f'Vocabulary size: {vocab_size}')

    # Model parameters
    input_length = 60
    hidden_size = 512
    output_size = 6203  # Total number of ayat

    # Load the trained model
    print('\nLoading trained model...')
    checkpoint = torch.load('quran_matcher_combined_6_to_10_words.pth', map_location='cpu')

    # Create model with same architecture
    model = QuranMatcherModel(
        vocab_size=vocab_size,
        input_length=input_length,
        hidden_size=hidden_size,
        output_size=output_size
    )

    # Load trained weights
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()

    print(f'Model loaded successfully\!')
    print(f'Training accuracy: {checkpoint["accuracy"]:.2f}%')

    # Create example input for tracing
    example_input = torch.randint(0, vocab_size, (1, input_length), dtype=torch.long)

    # Trace the model
    print('\nTracing model...')
    traced_model = torch.jit.trace(model, example_input)

    # Convert to CoreML
    print('Converting to CoreML...')
    mlmodel = ct.convert(
        traced_model,
        inputs=[ct.TensorType(name="input", shape=(1, input_length), dtype=int)],
        outputs=[ct.TensorType(name="output")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS16
    )

    # Add metadata
    mlmodel.author = 'Amr Aboelela'
    mlmodel.license = 'MIT'
    mlmodel.short_description = 'Quran verse matcher trained on 6-10 word prefixes'
    mlmodel.version = '1.0'

    # Set input/output descriptions
    mlmodel.input_description['input'] = 'Tokenized Arabic text (60 tokens)'
    mlmodel.output_description['output'] = 'Ayah index predictions (6203 classes)'

    # Save the model
    output_path = 'QuranMatcher_6to10words.mlpackage'
    mlmodel.save(output_path)
    print(f'\n✓ CoreML model saved to: {output_path}')

    # Print model info
    print(f'\nModel Information:')
    print(f'  Input shape: (1, {input_length})')
    print(f'  Output shape: (1, {output_size})')
    print(f'  Vocabulary size: {vocab_size}')
    print(f'  Hidden size: {hidden_size}')
    print(f'  Training accuracy: {checkpoint["accuracy"]:.2f}%')
    print(f'  Format: ML Program (iOS 16+)')

    return mlmodel

if __name__ == '__main__':
    try:
        mlmodel = convert_to_coreml()
        print('\n✓ Conversion completed successfully\!')
    except Exception as e:
        print(f'\n✗ Error during conversion: {e}')
        import traceback
        traceback.print_exc()
