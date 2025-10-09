# Muhaffez Project Instructions for Claude Code

## Project Overview
Muhaffez is an iOS Quran memorization companion app built with SwiftUI that helps users memorize and review the Holy Quran through voice recognition and smart matching.

## Code Style & Conventions
- **Language**: Swift 5+, SwiftUI framework
- **Indentation**: 2 spaces (not tabs)
- **Naming**: camelCase for variables/functions, PascalCase for types
- **Comments**: Use `//` for single-line comments
- **Header Comments**: Include file name, project name, and author in all new files:
  ```swift
  //
  //  FileName.swift
  //  Muhaffez
  //
  //  Created by Amr Aboelela on MM/DD/YY.
  //
  ```

## Project Structure
- `MuhaffezApp.swift` - Main app entry point with Speech recognition authorization
- `MuhaffezView.swift` - Main view with two-page Quran display
- `MuhaffezViewModel.swift` - Core view model handling speech recognition and text matching
- `QuranModel.swift` - Singleton model managing Quran text, pages, rub3, and surah markers
- `ArabicSpeechRecognizer.swift` - Speech recognition wrapper
- `quran-simple-min.txt` - Tanzil Quran text (simple minimal version 1.1)

## Key Features
1. **Speech Recognition**: Uses Apple's Speech framework for Arabic voice recognition
2. **Smart Text Matching**: Fuzzy matching for Quran text with normalization of Arabic characters
3. **Color-Coded Feedback**: Dark green for correct words, red for mistakes
4. **Two-Page Display**: Mimics physical Quran layout with left/right pages
5. **Navigation**: Juz, Surah, and page-based navigation

## Quran Text Format (`quran-simple-min.txt`)
- One ayah per line in simplified Arabic text
- Empty lines mark page breaks (`pageMarkers`)
- `*` marks rub3 (quarter-juz) boundaries (`rub3Markers`)
- `-` marks surah boundaries (`surahMarkers`)

## Important Notes
- **DO NOT modify** the Quran text file - it's from Tanzil Project under Creative Commons Attribution 3.0
- When creating tests, use Swift Testing framework (`import Testing`) not XCTest
- Always use local git user email, not Anthropic email
- Prefer editing existing files over creating new ones
- Only create documentation files if explicitly requested

## Dependencies
- SwiftUI
- Speech framework
- AVFoundation
- No external package dependencies

## Common Tasks
- **Adding features**: Consider impact on MuhaffezViewModel and QuranModel
- **UI changes**: Focus on MuhaffezView.swift and TwoPagesView.swift
- **Text processing**: See String.swift for Arabic text extensions
- **Navigation**: QuranModel provides page/juz/surah lookups

## Testing
- Use Swift Testing framework for unit tests
- Import `Testing` instead of `XCTest`

## Attribution
All code created by Amr Aboelela
