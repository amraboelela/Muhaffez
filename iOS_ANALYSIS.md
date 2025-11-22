# iOS Muhaffez CoreML & Arabic Text Processing Analysis

## 1. CoreML Model Implementation

### 1.1 Model Files Location
- **QuranSeq2Seq Model**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/QuranSeq2Seq.mlpackage/Data/com.apple.CoreML/model.mlmodel` (58.4 KB)
- **AyaFinder Model**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/AyaFinder.mlpackage/Data/com.apple.CoreML/model.mlmodel` (3.4 KB) 
- **Vocabulary File**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/vocabulary.json` (14,757 lines)

### 1.2 Model Wrapper Class: AyaFinderMLModel.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/AyaFinderMLModel.swift` (182 lines)

#### Architecture:
- Uses **QuranSeq2Seq** CoreML model (different from Android's TensorFlow Lite "aya_finder.tflite")
- **Input**: Word-level sequence-to-sequence model, not character-level
- **Output**: Autoregressive generation of Quranic ayat

#### Key Components:

**Special Tokens** (lines 17-22):
```swift
private var padToken: Int = 0      // <pad>
private var bosToken: Int = 1      // <s>
private var eosToken: Int = 2      // </s>
private var readerToken: Int = 3   // القاريء:
private var ayahToken: Int = 4     // الاية:
```

**Vocabulary Loading** (lines 40-63):
- Loads `vocabulary.json` as a JSON array of strings
- Builds bidirectional word-to-index mappings
- Special tokens are stored at fixed indices (0-4)
- Total vocabulary: Multiple thousands of unique words

**Prediction Algorithm** (lines 65-181):

1. **Input Normalization** (lines 71-80):
   - Splits text by spaces into words
   - Takes first 6 words maximum (line 88)
   - Skips out-of-vocabulary words with warning

2. **Sequence Building** (lines 84-104):
   - Prepends: `[<s>, القاريء:]`
   - Appends input words
   - Appends: `[الاية:]`
   - Minimum 3 vocabulary words required (line 107)

3. **Autoregressive Generation** (lines 112-175):
   - Generates up to 6 output words (line 114)
   - Creates MLMultiArray for current sequence at each step
   - Runs inference with dynamic sequence length
   - Selects token with highest logit for next position
   - Stops at `</s>` token
   - Returns predicted words joined with spaces

#### Model Input/Output:
- **Input**: MLMultiArray shapes [1, sequence_length] for both input_ids and attention_mask
- **Output**: Logits with shape [1, sequence_length, vocab_size]
- **Inference Type**: Encoder-Decoder (Seq2Seq) architecture
- **Dynamic Sequence Length**: Supports variable-length inputs (no padding to fixed length)

#### Handling Errors (lines 132-140):
- MLMultiArray creation failures
- Inference failures with detailed shape reporting
- Returns nil if prediction fails

---

## 2. A'ozo Bellah ("أعوذ بالله من الشيطان الرجيم") Handling

### 2.1 Detection: String.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/String.swift` (lines 83-101)

```swift
var hasA3ozoBellah: Bool {
    // A3ozoBellah: "أعوذ بالله من الشيطان الرجيم"
    let a3ozoWords = ["اعوذ", "بالله", "من", "الشيطان", "الرجيم"]
    let normalizedText = self.normalizedArabic
    let words = normalizedText.split(separator: " ").map { String($0) }
    
    // Need at least 5 words to check
    guard words.count >= 5 else { return false }
    
    // Check similarity of first 5 words to a3ozo words
    let similarityThreshold = 0.8
    for i in 0..<4 {  // Note: Only checks first 4 words\!
        let similarity = words[i].similarity(to: a3ozoWords[i])
        if similarity < similarityThreshold {
            return false
        }
    }
    return true
}
```

**Key Details**:
- Normalized words stored (without diacritics)
- Similarity threshold: 0.8 (80%)
- Only checks first 4 of the 5 words
- Uses Levenshtein distance for similarity calculation

### 2.2 Removal: String.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/String.swift` (lines 77-81)

```swift
var removeA3ozoBellah: String {
    let words = self.split(separator: " ")
    guard words.count >= 5 else { return self }
    return words.dropFirst(5).joined(separator: " ")
}
```

**Behavior**:
- Simply drops first 5 words if text has 5+ words
- Returns original text if less than 5 words
- Does NOT validate if text actually contains A'ozo Bellah

### 2.3 State Tracking: MuhaffezViewModel.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/MuhaffezViewModel.swift` (lines 43-46, 148-164)

**State Variable** (lines 43-47):
```swift
var voiceTextHasA3ozoBellah = false {
    didSet {
        updateTextToPredict()
    }
}
```

**Detection Function** (lines 148-164):
```swift
private func checkA3ozoBellah() {
    guard \!textToPredict.isEmpty && \!voiceTextHasA3ozoBellah else {
        return
    }
    // Check if a3ozoBellah is present (with fuzzy matching for mistakes)
    if quranModel.a3ozoBellah.hasPrefix(textToPredict) || 
       textToPredict.hasPrefix(quranModel.a3ozoBellah) {
        print("checkA3ozoBellah, voiceTextHasA3ozoBellah = true")
        voiceTextHasA3ozoBellah = true
    } else {
        // Try fuzzy matching for common mistakes
        let similarity = textToPredict.similarity(to: quranModel.a3ozoBellah)
        if similarity >= 0.7 {
            print("checkA3ozoBellah, fuzzy match with similarity: \(similarity)")
            voiceTextHasA3ozoBellah = true
        }
    }
}
```

**Detection Logic**:
1. First checks for exact prefix match (either direction)
2. Falls back to fuzzy similarity matching (threshold: 0.7 = 70%)
3. Once detected, flag prevents re-detection

### 2.4 Automatic Detection: MuhaffezViewModel.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/MuhaffezViewModel.swift` (lines 17-31)

In `voiceText` property observer:
```swift
var voiceText = "" {
    didSet {
        textToPredict = voiceText.normalizedArabic
        updateTextToPredict()
        checkA3ozoBellah()  // <-- Called automatically
        if \!voiceText.isEmpty {
            // ... update foundAyat and matchedWords
        }
    }
}
```

---

## 3. Basmallah ("بسم الله الرحمن الرحيم") Handling

### 3.1 Detection: String.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/String.swift` (lines 34-75)

```swift
var removeBasmallah: String {
    // Expected Bismillah words: ["بسم", "الله", "الرحمن", "الرحيم"]
    let bismillahWords = ["بسم", "الله", "الرحمن", "الرحيم"]
    let normalizedText = self.normalizedArabic
    let words = normalizedText.split(separator: " ").map { String($0) }
    
    // Need at least 3 words to check for incomplete Bismillah
    guard words.count >= 3 else { return self }
    
    // Check if starts with "بسم الله"
    let similarityThreshold = 0.8
    if words[0].similarity(to: bismillahWords[0]) < similarityThreshold ||
       words[1].similarity(to: bismillahWords[1]) < similarityThreshold {
        return self // Doesn't start with Bismillah, return unchanged
    }
    
    // Check if we have 4 words and they match full Bismillah
    if words.count >= 4 {
        let word2Matches = words[2].similarity(to: bismillahWords[2]) >= similarityThreshold
        let word3Matches = words[3].similarity(to: bismillahWords[3]) >= similarityThreshold
        
        if word2Matches && word3Matches {
            // Full Bismillah: drop first 4 words
            return words.dropFirst(4).joined(separator: " ")
        }
    }
    
    // Check for incomplete Bismillah (3 words)
    if words.count >= 3 {
        // Case 1: "بسم الله الرحمن" (missing "الرحيم")
        if words[2].similarity(to: bismillahWords[2]) >= similarityThreshold {
            return words.dropFirst(3).joined(separator: " ")
        }
        // Case 2: "بسم الله الرحيم" (missing "الرحمن")
        if words[2].similarity(to: bismillahWords[3]) >= similarityThreshold {
            return words.dropFirst(3).joined(separator: " ")
        }
    }
    
    // Doesn't match Bismillah pattern, return unchanged
    return self
}
```

**Key Details**:
- Similarity threshold: 0.8 (80%)
- Handles full Bismillah (4 words): removes all 4
- Handles incomplete variations:
  - "بسم الله الرحمن" → removes first 3
  - "بسم الله الرحيم" → removes first 3
- Only checks if text starts with "بسم الله" pattern

### 3.2 State Tracking: MuhaffezViewModel.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/MuhaffezViewModel.swift` (lines 38-46, 166-179)

**State Variable** (lines 38-42):
```swift
var voiceTextHasBesmillah = false {
    didSet {
        updateTextToPredict()
    }
}
```

**Detection Function** (lines 166-179):
```swift
private func checkBismellah() {
    guard \!textToPredict.isEmpty && \!voiceTextHasBesmillah else {
        return
    }
    foundAyat = []
    
    // First pass: check if bismillah is present
    if quranModel.bismellah.hasPrefix(textToPredict) || 
       textToPredict.hasPrefix(quranModel.bismellah) {
        print("findMatchingAyat, voiceTextHasBesmillah = true")
        voiceTextHasBesmillah = true
    }
}
```

**Detection Logic**:
1. Checks bidirectional prefix match with stored normalized Basmallah
2. Sets flag without attempting fuzzy matching (unlike A'ozo)
3. Clears foundAyat when detected

### 3.3 Removal Order: MuhaffezViewModel.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/MuhaffezViewModel.swift` (lines 49-59)

```swift
private func updateTextToPredict() {
    var text = voiceText.normalizedArabic
    if voiceTextHasA3ozoBellah {
        text = text.removeA3ozoBellah  // Remove first (5 words)
    }
    if voiceTextHasBesmillah {
        text = text.removeBasmallah    // Remove second (3-4 words)
    }
    textToPredict = text
}
```

**Removal Order**:
1. A'ozo Bellah removed FIRST (5 words)
2. Basmallah removed SECOND (3-4 words)
3. Remaining text used for ayah matching

### 3.4 Storage in QuranModel: QuranModel.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/QuranModel.swift` (lines 14-20, 168-170)

```swift
let bismellah: String
let a3ozoBellah: String

// ... in init:
self.a3ozoBellah = normalizedQuranLines[0]
self.bismellah = normalizedQuranLines[1]
```

**Storage**:
- A'ozo Bellah stored as first line of Quran (index 0)
- Basmallah stored as second line (index 1)
- Both stored in normalized form (no diacritics)

### 3.5 Test Coverage: MuhaffezViewModelTests.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/MuhaffezTests/MuhaffezViewModelTests.swift` (lines 52-159)

Tests include:
- Exact Basmallah detection (line 56)
- Basmallah followed by other ayat (line 64)
- A'ozo Bellah detection (line 102)
- A'ozo with fuzzy matching (line 118)
- Both A'ozo and Basmallah together (line 128)
- Combined with Surah An-Nas (lines 71, 126)

---

## 4. String Extensions & Arabic Text Normalization

### 4.1 Text Normalization: String.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/String.swift` (lines 10-32)

```swift
// Remove all Arabic diacritics (tashkeel)
var removingTashkeel: String {
    String(self.unicodeScalars.filter {
        \!CharacterSet.arabicDiacritics.contains($0)
    })
}

func removingControlCharacters() -> String {
    self.replacingOccurrences(of: "\\p{Cf}", with: "", options: .regularExpression)
}

var normalizedArabic: String {
    // 1. Remove diacritics (tashkeel) and control characters
    var text = self.removingTashkeel.removingControlCharacters()
    
    // 2. Normalize hamza variants
    let hamzaMap: [Character: Character] = [
        "إ": "ا", "أ": "ا", "آ": "ا"
    ]
    text = String(text.map { hamzaMap[$0] ?? $0 })
    return text
}
```

**Normalization Steps**:
1. Remove tashkeel (harakat) using CharacterSet
2. Remove control characters (unicode category Cf)
3. Normalize hamza variants to base alif "ا"

### 4.2 Arabic Diacritics Character Set: CharacterSet.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/CharacterSet.swift` (lines 10-18)

```swift
static let arabicDiacritics: CharacterSet = {
    var set = CharacterSet()
    // Harakat: fatha, damma, kasra, sukun, shadda, etc.
    set.insert(charactersIn: "\u{064B}"..."\u{065F}")
    // dagger alif
    set.insert("\u{0670}")
    return set
}()
```

**Diacritics Covered**:
- Unicode range 064B-065F (Arabic diacritical marks)
- Dagger alif (ٰ - U+0670)

### 4.3 Similarity Calculation: String.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/String.swift` (lines 123-160)

```swift
// Levenshtein distance
func levenshteinDistance(to target: String) -> Int {
    let sourceArray = Array(self)
    let targetArray = Array(target)
    let (n, m) = (sourceArray.count, targetArray.count)
    
    if n == 0 { return m }
    if m == 0 { return n }
    
    var dist = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
    
    for i in 0...n { dist[i][0] = i }
    for j in 0...m { dist[0][j] = j }
    
    for i in 1...n {
        for j in 1...m {
            if sourceArray[i - 1] == targetArray[j - 1] {
                dist[i][j] = dist[i - 1][j - 1]
            } else {
                dist[i][j] = Swift.min(
                    dist[i - 1][j] + 1,
                    dist[i][j - 1] + 1,
                    dist[i - 1][j - 1] + 1
                )
            }
        }
    }
    return dist[n][m]
}

// Similarity ratio (0...1)
func similarity(to other: String) -> Double {
    let maxLen = max(self.count, other.count)
    if maxLen == 0 { return 1.0 }
    let dist = self.levenshteinDistance(to: other)
    return 1.0 - Double(dist) / Double(maxLen)
}
```

**Algorithm**:
- Dynamic programming implementation
- Distance = max(insertions, deletions, substitutions)
- Similarity = 1.0 - (distance / max_length)

### 4.4 Search Utilities: String.swift
**Location**: `/Users/amraboelela/develop/swift/muhaffez/Muhaffez/String.swift` (lines 103-121)

```swift
func findIn(lines: [String]) -> String? {
    let normalizedSearch = self.normalizedArabic
    return lines.first { line in
        let normalizedLine = line.normalizedArabic
        return normalizedLine.contains(normalizedSearch)
    }
}

func findLineStartingIn(lines: [String]) -> (line: String, index: Int)? {
    let normalizedSearch = self.normalizedArabic
    
    for (i, line) in lines.enumerated() {
        if line.normalizedArabic.hasPrefix(normalizedSearch) {
            return (line, i)
        }
    }
    return nil
}
```

**Usage**:
- `findIn`: Finds any line containing normalized text
- `findLineStartingIn`: Finds line starting with normalized text prefix

---

## 5. Key Differences from Android Version

### 5.1 ML Model Architecture
| Aspect | iOS (Swift) | Android (Kotlin) |
|--------|------------|-----------------|
| Framework | CoreML | TensorFlow Lite |
| Model Format | `.mlpackage` (58 KB) | `.tflite` (~11 MB) |
| Tokenization | Word-level (vocabulary.json) | Character-level (60 tokens) |
| Architecture | Seq2Seq (autoregressive) | Single-shot classification |
| Input | Variable-length sequence | 60 fixed-length tokens |
| Output | Autoregressive word generation | 6203 ayah probability distribution |
| Max Input Words | 6 words | Not specified in codebase |
| Max Output Words | 6 words | Not applicable (classification) |

### 5.2 A'ozo Bellah Detection
| Aspect | iOS | Android |
|--------|-----|---------|
| Fuzzy Match Check | First 4 of 5 words only | All 5 words checked |
| Fuzzy Threshold | 0.8 (80%) | 0.7 (70%) |
| Prefix Match | Both directions | Not specified |
| Removal | Simple drop first 5 words | More sophisticated |

### 5.3 Basmallah Detection
| Aspect | iOS | Android |
|--------|-----|---------|
| Prefix Match | Yes (bidirectional) | Bidirectional check |
| Fuzzy Matching | NO (only exact/prefix) | Yes |
| Incomplete Variants | 2 variations handled | Multiple variations |
| Removal Logic | Complex matching with similarity | Similarity-based |

### 5.4 Vocabulary
- **iOS**: Word-level vocabulary (14,757 lines in vocabulary.json)
- **Android**: Character-level vocabulary (60 tokens)

### 5.5 Special Tokens
**iOS**:
- `<pad>` (0), `<s>` (1), `</s>` (2)
- `القاريء:` (3) - "the reader"
- `الاية:` (4) - "the ayah"

**Android**: 
- Character-level tokens only

---

## 6. Integration with ViewModel

### 6.1 MLModel Usage Flow: MuhaffezViewModel.swift

**When used** (lines 265-319):
1. Called during `performFallbackMatch()` (line 328)
2. Triggered after 1-second debounce if no prefix match found (line 224)
3. Capped input to first 6 words (lines 270-272)

**Fallback Chain**:
1. Fast prefix matching
2. ML Model (if no matches or <17 chars typed) → 1 second delay
3. Similarity matching (if ML fails)

### 6.2 State Updates After Detection
**Lines 281-282**:
```swift
checkA3ozoBellah()
checkBismellah()
```
These are called after ML model prediction to validate result

---

## 7. Test Coverage

### 7.1 String Extension Tests: StringTests.swift
- Tashkeel removal ✓
- Normalization ✓
- Hamza variant handling ✓
- Levenshtein distance ✓
- Similarity calculation ✓
- Basmallah removal (incomplete & full variants) ✓
- A'ozo Bellah removal & detection ✓

### 7.2 ViewModel Integration Tests: MuhaffezViewModelTests.swift
- Bismillah detection & removal ✓
- A'ozo detection & fuzzy matching ✓
- Both markers together ✓
- Incomplete Bismillah variants ✓
- Complex combinations (An-Nas surah) ✓

### 7.3 ML Model Tests: AyaFinderMLModelTests.swift
- Correct input prediction ✓
- Distorted input handling ✓
- Partial input (first 3 words) ✓
- Word array input ✓

---

## 8. Important Implementation Notes

### 8.1 Normalization Always Happens
- Every input is normalized to `normalizedArabic` automatically
- Comparison always uses normalized form
- Original text preserved in `voiceText` property

### 8.2 Flag-Based Removal
- Both A'ozo and Basmallah use boolean flags
- Once set, flag prevents re-detection
- Removal order: A'ozo first, then Basmallah
- Flags reset with `resetData()`

### 8.3 Dynamic Model Input
- No padding to fixed length
- Sequence length varies per input
- Model handles variable dimensions with MLMultiArray

### 8.4 Autoregressive Generation
- Model predicts one word at a time
- Appends prediction to input for next iteration
- Stops at `</s>` token or after 6 words

---

## Files Summary

| File | Lines | Purpose |
|------|-------|---------|
| AyaFinderMLModel.swift | 182 | CoreML model wrapper, prediction logic |
| MuhaffezViewModel.swift | 511 | Main logic, A'ozo/Basmallah detection & removal |
| String.swift | 162 | Normalization, similarity, removal utilities |
| QuranModel.swift | 274 | Stores normalized A'ozo & Basmallah at indices 0-1 |
| MuhaffezViewModelTests.swift | 517 | Comprehensive test coverage |
| StringTests.swift | 207 | String extension tests |
| AyaFinderMLModelTests.swift | 116 | ML model prediction tests |
| CLAUDE.md | 116 | Project documentation |

