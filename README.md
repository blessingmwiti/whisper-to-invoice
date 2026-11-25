# Whisper to Invoice

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Gemma 4](https://img.shields.io/badge/Powered%20by-Gemma%204-blue)](https://ai.google.dev/gemma)
[![Offline](https://img.shields.io/badge/Works-100%25%20Offline-green)](https://github.com/google-ai-edge/gallery)

**Speak your sale. Get a professional invoice. No internet required.**

Whisper to Invoice is a fully offline Android app for small business owners anywhere in the world. Describe a sale out loud and Gemma 4 transcribes it, extracts the line items, quantities, prices, client name, and date, then generates a professional PDF invoice you can share instantly via WhatsApp or any other channel.

Built for anyone who runs a business on the move — freelancers, market traders, delivery operators, repair technicians, independent contractors — people who need invoices but have no time to type, unreliable connectivity, and real data privacy concerns.

---

## The Problem

Hundreds of millions of small business owners worldwide conduct transactions verbally but have no practical way to generate invoices on the spot. Existing invoicing tools require:

- Reliable internet connectivity
- Typing on small screens mid-transaction
- Technical literacy and onboarding
- Monthly subscription fees

This leaves most transactions undocumented, limiting access to credit, trade finance, and formal business relationships — a problem that cuts across every market and continent.

## The Solution

Whisper to Invoice removes every barrier:

1. **Speak** — describe your sale naturally, in whatever language you use
2. **Review** — Gemma 4 structures the invoice; edit any field before saving
3. **Share** — generate a PDF and send via WhatsApp in one tap

Everything runs on the device. Financial data never leaves the phone.

---

## How Gemma 4 Is Used

The app uses **Gemma 4 E2B** (2 billion parameter, instruction-tuned) running fully on-device via [Google AI Edge LiteRT](https://github.com/google-ai-edge/LiteRT-LM).

The model receives the audio recording alongside a structured prompt that instructs it to:

- Transcribe the spoken description (English, Swahili, or mixed code-switching)
- Extract structured invoice fields: client name, date, line items (description, quantity, unit price), currency, tax, and notes
- Return a strict JSON object — no prose, no markdown

The prompt handles Swahili number words (moja=1, mbili=2, tatu=3…) and defaults sensibly when fields are not mentioned (today's date, KES currency, zero tax).

Gemma 4's multimodal audio capabilities make this possible in a single inference call — no separate speech-to-text step, no server round-trip.

---

## Features

- **Voice-to-invoice** — speak a sale, get a structured invoice in seconds
- **Bilingual** — English, Swahili, and code-switched input
- **Fully editable** — correct any field, add/remove line items, set tax as a percentage
- **Business profile** — your name, address, logo, and payment instructions appear on every invoice
- **PDF generation** — professional A4 invoice, generated on-device, no libraries required
- **WhatsApp share** — one tap to share the PDF with your client
- **Invoice history** — all past invoices saved locally, re-shareable at any time
- **100% offline** — after the one-time model download, no internet ever required
- **Privacy first** — financial data never leaves the device

---

## Getting Started

### Requirements

- Android 12+ (API 31+)
- 4 GB+ RAM recommended for Gemma 4 E2B
- ~2.6 GB free storage for model download
- Microphone permission

### Build

```bash
git clone https://github.com/YOUR_USERNAME/whisper-to-invoice
cd whisper-to-invoice/Android/src
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

> **Note:** LiteRT does not run in the Android emulator. A physical device is required.

### First Launch

On first launch the app will prompt you to download Gemma 4 E2B (~2.6 GB). After that, everything works offline permanently.

---

## Attribution

This project is a fork of [**Google AI Edge Gallery**](https://github.com/google-ai-edge/gallery) — an open-source Android app for exploring on-device generative AI, maintained by Google.

The following components from Edge Gallery are used as-is or with minor modifications:

- `LiteRT` model loading and inference infrastructure (`LlmChatModelHelper`)
- `AudioRecorderPanel` — audio capture UI and PCM recording
- `ModelManagerViewModel` — model download, initialization, and lifecycle
- `GalleryNavGraph` — navigation host structure
- `HomeScreen` — drawer layout and `SquareDrawerItem` composable
- Hilt dependency injection setup and `CustomTask` multibinding pattern
- Theme, typography, and color system

All original Google LLC code is licensed under the **Apache License 2.0**. All new code in the `invoiceextraction` package is original work.

> **Original repository:** https://github.com/google-ai-edge/gallery  
> **License:** Apache 2.0 — see [LICENSE](LICENSE)

---

## License

Licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.

---

## Links

- [Google AI Edge Gallery](https://github.com/google-ai-edge/gallery)
- [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM)
- [Gemma models](https://ai.google.dev/gemma)
- [Google AI Edge documentation](https://ai.google.dev/edge)
