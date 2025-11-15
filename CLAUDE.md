# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Muhaffez is an iOS Quran memorization companion app built with SwiftUI that helps users memorize and review the Holy Quran through voice recognition and intelligent text matching.

## Build & Test Commands

### Building
```bash
xcodebuild -scheme Muhaffez -configuration Debug build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -scheme Muhaffez -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class (use Swift Testing framework, not XCTest)
xcodebuild test -scheme Muhaffez -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MuhaffezTests/QuranModelTests

# Run single test method
xcodebuild test -scheme Muhaffez -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MuhaffezTests/QuranModelTests/testPageNumber
```

## Architecture Overview

### MVVM Pattern
- **MuhaffezViewModel**: Main view model orchestrating speech recognition, text matching, and page rendering
  - `MuhaffezViewModel+TwoPages.swift`: Extension handling two-page Quran layout rendering
- **QuranModel**: Singleton managing Quran text data, page/juz/surah markers and lookups
- **PageModel**: Value type for page display state (juz, surah, page number, attributed text)
- **MuhaffezView**: Main SwiftUI view with controls
- **TwoPagesView**: Displays left/right Quran pages side-by-side

### Text Matching Pipeline
1. **Speech Recognition** → `ArabicSpeechRecognizer` captures voice input
2. **Normalization** → `String.normalizedArabic` removes tashkeel, normalizes hamza variants
3. **Ayah Detection** → `updateFoundAyat()` uses:
   - Fast prefix matching first
   - ML model prediction (`AyaFinderMLModel`) as fallback
   - Similarity scoring for final validation
4. **Word Matching** → `updateMatchedWords()` with fuzzy matching:
   - Forward search (up to 17 words ahead)
   - Backward search (up to 10 words back)
   - Similarity thresholds: 0.7 (match), 0.6 (simi-match), 0.95 (seek)
5. **Page Rendering** → `updatePages()` builds AttributedString with color-coded feedback

### ML Model Integration
- **AyaFinderMLModel**: Neural network (PyTorch converted to CoreML)
- Input: 100-token character sequence
- Output: Probability distribution over 6,203 ayat
- Returns top 5 predictions with probabilities
- Training code in `ai/` directory (Python/PyTorch)

### Quran Text Format (`quran-simple-min.txt`)
- Source: Tanzil Project (Creative Commons Attribution 3.0)
- **DO NOT MODIFY** this file
- Format:
  - One ayah per line (6,203 total)
  - Empty line = page break
  - `*` = rub3 (quarter-juz) marker
  - `-` = surah boundary

## Code Style

### Swift Conventions
- **Indentation**: 2 spaces (not tabs)
- **Naming**: camelCase for variables/functions, PascalCase for types
- **Optional unwrapping**: Use `if let handler {` not `if let handler = handler {`

### File Headers
```swift
//
//  FileName.swift
//  Muhaffez
//
//  Created by Amr Aboelela on MM/DD/YY.
//
```

### Testing
- Use Swift Testing framework: `import Testing`
- **NOT** XCTest

## Key Extensions & Utilities

### String Extensions (`String.swift`)
- `normalizedArabic`: Remove tashkeel, normalize hamza variants
- `removeBasmallah` / `removeA3ozoBellah`: Strip opening phrases
- `similarity(to:)`: Levenshtein distance-based similarity (0.0-1.0)
- `findIn(lines:)` / `findLineStartingIn(lines:)`: Search helpers

### CharacterSet (`CharacterSet.swift`)
- `arabicDiacritics`: Character set for tashkeel removal

## Navigation & Markers

QuranModel provides:
- `pageNumber(forAyahIndex:)`: Ayah index → page number (1-604)
- `juzNumberFor(ayahIndex:)`: Ayah index → juz number (1-30)
- `surahNameFor(ayahIndex:)`: Ayah index → surah name
- `rub3NumberFor(ayahIndex:)`: Ayah index → rub3 number (1-240)
- `isRightPage(forAyahIndex:)`: Determines left/right page for two-page layout

## Important Notes
- All code created by Amr Aboelela
- Speech recognition requires microphone and Speech framework authorization
- Two-page layout mimics physical Mushaf (right pages are odd-numbered)
- Color feedback: dark green = correct, red = incorrect/unmatched
- Supports automatic detection of "بسم الله الرحمن الرحيم" and "أعوذ بالله من الشيطان الرجيم"
- from now on, do not run the train.sh let me do that for you