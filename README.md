# Muhaffez

📖 **Muhaffez** (محفظ) is an iOS Quran memorization companion app designed to help you on your journey of learning, reviewing, and perfecting the words of Allah through advanced voice recognition and intelligent text matching.

---

## 🌟 Features

### Core Functionality
- 🕌 **Memorization Aid**
  Listen, repeat, and test yourself on any Surah, Juz, or page with real-time feedback.

- 🔍 **Smart Matching**
  Advanced Arabic text matching with support for **fuzzy matching** that handles:
  - Hamza variants (ء، أ، إ، آ، ئ، ؤ)
  - Tashkeel (diacritical marks) normalization
  - Common recitation variations
  - Alef variants and Ya/Alef Maqsurah differences

- 🎙️ **Arabic Voice Recognition**
  Powered by Apple's Speech framework with Arabic language support, comparing your recitation word-by-word in real-time.

- 🎨 **Color-Coded Feedback**
  Visual feedback system:
  - **Dark Green**: Correctly recited words
  - **Red**: Mistakes or mismatches
  - Easy error identification for focused review

- 📖 **Two-Page Layout**
  Authentic Quran reading experience with side-by-side page display mimicking physical Mushaf layout.

- 🧭 **Navigation**
  Navigate by:
  - Juz (1-30)
  - Surah (114 surahs)
  - Page (1-604)
  - Rub3 (quarter-juz) markers

### Coming Soon
- 📅 **Progress Tracking**
  Track memorization progress, review history, and mastery levels for each section.

---

## 🛠️ Technology Stack

- **Framework**: SwiftUI (iOS 15+)
- **Speech Recognition**: Apple Speech framework with Arabic support
- **Language**: Swift 5+
- **Architecture**: MVVM pattern
- **Text Processing**: Custom Arabic normalization and fuzzy matching algorithms

---

## 📱 Requirements

- iOS 15.0 or later
- Microphone access for voice recognition
- Speech recognition authorization

---

## 🚀 Getting Started

1. Clone the repository
2. Open `Muhaffez.xcodeproj` in Xcode
3. Build and run on simulator or device
4. Grant microphone and speech recognition permissions when prompted
5. Start memorizing!

---

## 📖 Quran Text Source

This application uses the **Tanzil Quran Text** (Simple Minimal, Version 1.1)

**Copyright:** (C) 2007-2025 Tanzil Project
**License:** Creative Commons Attribution 3.0
**Website:** [tanzil.net](http://tanzil.net)

The Tanzil Quran text is carefully produced, highly verified, and continuously monitored by a group of specialists at Tanzil Project. We are grateful for their meticulous work in providing accurate Quranic text to the community.

### Terms of Use

- Permission is granted to copy and distribute verbatim copies of this text, but **CHANGING IT IS NOT ALLOWED**.

- This Quran text can be used in any website or application, provided that its source (Tanzil Project) is clearly indicated, and a link is made to [tanzil.net](http://tanzil.net) to enable users to keep track of changes.

- This copyright notice shall be included in all verbatim copies of the text, and shall be reproduced appropriately in all files derived from or containing substantial portion of this text.

Please check for updates at: [http://tanzil.net/updates/](http://tanzil.net/updates/)

---

## 👨‍💻 Author

Created by Amr Aboelela

---

## 📄 License

This project uses the Tanzil Quran Text under Creative Commons Attribution 3.0 license. The application code follows its own licensing terms.
