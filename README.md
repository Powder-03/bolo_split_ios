# BoloSplit (iOS)

> **Just speak your expenses.** A voice-first, Splitwise-style iOS expense-splitting app built with SwiftUI, supporting natural **Hindi, Hinglish, and English** voice commands, real-time audio metering, spoken confirmations, and Home/Lock Screen widgets.

---

## Demo & Screenshots

> **Media Placeholders:** Capture screen recordings and screenshots during real iPhone testing and drop them into `docs/media/` (or drag-and-drop MP4/MOV files directly into GitHub's README editor).

### Video Walkthrough

<!-- Replace the placeholder below after recording on your iPhone (Control Center -> Screen Recording) -->
<!-- Option A (GitHub drag-and-drop MP4): paste the uploaded GitHub asset URL on its own line -->
<!-- Option B (GIF preview): ![BoloSplit iOS Demo](docs/media/demo.gif) -->

| Voice Expense Logging & TTS Demo | Full App Walkthrough |
| :---: | :---: |
| *Add voice-overlay demo video / GIF here (`docs/media/voice-demo.gif`)* | *Add end-to-end iPhone walkthrough video here* |

### Screenshots

| Login & Voice Overlay | Friends & Balances | Group Ledger |
| :---: | :---: | :---: |
| ![Login Screen](docs/media/01-login.png) | ![Friends Tab](docs/media/02-friends.png) | ![Group Detail](docs/media/03-group-detail.png) |

| Voice Listening Orb | Self (Personal) Spend | Activity & Settle Up |
| :---: | :---: | :---: |
| ![Voice Overlay](docs/media/04-voice-overlay.png) | ![Self Tab](docs/media/05-self.png) | ![Activity Tab](docs/media/06-activity.png) |

| Home & Lock Screen Widget |
| :---: |
| ![Quick Bolo Widget](docs/media/07-widget.png) |

---

## Features (iOS)

### Voice-First Expense Engine (`Bolo` Mic)
- **Floating Siri-Style Trigger:** Persistent animated `Bolo` capsule across tabs with ambient pulse ring and haptic feedback.
- **Live Audio Capture & Metering:** Records 16 kHz mono `.m4a` (AAC) via `AVAudioRecorder` with 30 Hz normalized decibel metering driving a 7-bar reactive waveform and dual counter-rotating glowing orb rings.
- **Voice + Text Fallback:** Speak naturally (*"Aaj Rahul aur Priya ke saath 900 ka dinner split kar do"*) or switch inline to typed commands (`POST /voice/audio` and `POST /voice/text`).
- **Spoken Confirmations & Ambiguity Handling:** Plays Hinglish/English confirmations with `AVSpeechSynthesizer` (`en-IN` / `en-US`, with persistent mute toggle) and prompts cleanly when a name or group is ambiguous.

### Ledger & Splitting UX
- **Friends:** Net balance banner (`Owed to you` vs `You owe` ratio bar), searchable friend list, gliding balance filter chips (`All`, `Owed to you`, `You owe`, `Settled`), friend detail timelines, and instant settle-up with undo.
- **Groups:** Create groups or join via invite code, one-tap copy invite code with animated feedback, member roster balances, group-scoped `Bolo in Group` voice capture, and manual expense creation.
- **Self (Personal Expenses):** Track solo expenses in INR (`₹`) with a stacked category breakdown bar and gliding category filter chips.
- **Activity Feed:** Unified timeline grouped into `Today`, `Yesterday`, `This Week`, and `Earlier`, searchable and filterable by `All`, `Expenses`, `Settlements`, and `Personal`, with swipe-to-delete and undo.
- **Manual Expense Form:** Equal and exact splits with paise-accurate rounding validation.

### iOS Ecosystem & Polish
- **WidgetKit (`BoloSplitWidget`):** `Quick Bolo` widget in `.systemSmall`, `.accessoryCircular`, and `.accessoryRectangular` families launching straight into voice capture via `bolosplit://voice`.
- **Deep Linking:** Handles `bolosplit://voice` (including queuing the voice overlay if opened while signed out and presenting it immediately after login).
- **Motion & Accessibility:** Custom `AppMotion` springs, staggered card entrances, shimmer skeleton loading states, numeric text transitions, tactile `UIImpactFeedbackGenerator` / `.sensoryFeedback` haptics, and full `@Environment(\.accessibilityReduceMotion)` support.

---

## Tech Stack & Architecture

- **Platform:** iOS 17.6+ (Swift 5, SwiftUI, `@Observable` macro, Swift Concurrency with `@MainActor` isolation)
- **Architecture:** Protocol-backed **MVVM + Services** wired through a central `AppEnvironment` container
- **Audio & Speech:** `AVFoundation` (`AVAudioRecorder`, `AVAudioSession`, `AVSpeechSynthesizer`)
- **Authentication:** `FirebaseAuth` + `GoogleSignIn-iOS` (with `#if DEBUG` `X-User-Email` fallback for fast testing)
- **Networking:** Native `URLSession` `APIClient` with automatic 401 Firebase token refresh, 60s timeout (accommodating backend cold starts & AI inference), and multipart `audio/m4a` upload
- **Extensions & Tests:** `BoloSplitWidget` (WidgetKit) + `BoloSplitTests` (XCTest with protocol mocks)

### Swift Package Dependencies
Managed via Swift Package Manager inside `BoloSplit.xcodeproj`:
- `firebase-ios-sdk` (`FirebaseCore`, `FirebaseAuth`)
- `GoogleSignIn-iOS` (`GoogleSignIn`, `GoogleSignInSwift`)

---

## Project Structure

```text
BoloSplit/
├── BoloSplit/
│   ├── BoloSplitApp.swift                # Firebase setup, Google Sign-In & bolosplit:// deep links
│   ├── ContentView.swift                 # Auth gate & root transition
│   ├── Info.plist                        # Custom URL schemes (bolosplit + Google REVERSED_CLIENT_ID)
│   ├── GoogleService-Info.plist          # Firebase client configuration
│   ├── App/
│   │   ├── AppEnvironment.swift          # DI container & deep link / feed coordination
│   │   └── MainTabView.swift             # 5-tab shell + floating Bolo button
│   ├── Core/
│   │   ├── Config/AppConfig.swift        # Production & local backend base URLs
│   │   ├── Auth/                         # AuthService, AuthViewModel
│   │   ├── Audio/                        # AudioRecorderService (.m4a), SpeechPlaybackService (TTS)
│   │   └── Networking/                   # APIClient, Endpoint, LedgerService, VoiceService, JSONCoders
│   ├── Features/
│   │   ├── Voice/                        # SiriVoiceOverlayView & VoiceViewModel
│   │   ├── Friends/                      # FriendsTabView, FriendDetailView, AddFriendSheet
│   │   ├── Groups/                       # GroupsTabView, GroupDetailView, CreateOrJoinGroupSheet
│   │   ├── Self/                         # SelfTabView & SelfTabViewModel
│   │   ├── Activity/                     # ActivityTabView & ActivityTabViewModel
│   │   ├── Expenses/                     # ExpenseDetailView & ManualExpenseFormView
│   │   ├── Settlements/                  # SettleUpSheet & SettleUpViewModel
│   │   └── Account/                      # LoginView & AccountTabView
│   ├── Models/                           # Balance, Friend, Group, Expense, Settlement, Voice models
│   └── SharedUI/                         # AppTheme, BalanceBannerCard, EmptyStateView, MotionAndFeedback
├── BoloSplitWidget/
│   └── BoloSplitWidget.swift             # Home & Lock Screen Quick Bolo widget
└── BoloSplitTests/
    ├── BoloSplitTests.swift              # Paise math, FastAPI JSON decoding & deep link tests
    ├── FriendsTabViewModelTests.swift
    ├── SettleUpViewModelTests.swift
    ├── VoiceViewModelTests.swift
    └── Mocks/                            # Protocol mocks for Ledger, Voice, Audio & Speech
```

---

## Running & Testing on iPhone

### 1. Prerequisites
- **Xcode 16+** (with iOS 17.6+ SDK)
- Physical **iPhone running iOS 17.6+** (recommended for testing real microphone capture, Bluetooth/speaker routing, and haptics)
- An Apple Developer Team (Personal Team works for local device builds)

### 2. Open & Configure Signing
1. Open `BoloSplit.xcodeproj` in Xcode.
2. Wait for Swift Package Manager to resolve `firebase-ios-sdk` and `GoogleSignIn-iOS`.
3. Select your Apple Developer **Team** under **Signing & Capabilities** for **all three targets** (update bundle IDs if needed for your team):
   - `BoloSplit` (`BoloSplit.BoloSplit`)
   - `BoloSplitWidget` (`BoloSplit.BoloSplit.BoloSplitWidget`)
   - `BoloSplitTests` (`BoloSplit.BoloSplitTests`)
4. Ensure `BoloSplit/GoogleService-Info.plist` matches your Firebase project and that its `REVERSED_CLIENT_ID` matches the URL scheme in `BoloSplit/Info.plist`.

### 3. Configure Backend URL
Edit `BoloSplit/Core/Config/AppConfig.swift`:
- **Production (Render):** Uses `https://bolosplit.onrender.com` by default (note: free-tier Render instances may take ~30–50s on the first cold request; `requestTimeout` is set to `60s`).
- **Local FastAPI on Mac (Simulator):** Switch `AppConfig.baseURL` to `localBaseURL` (`http://127.0.0.1:8000`).
- **Local FastAPI on Real iPhone:** `127.0.0.1` points to the iPhone itself, so replace the host with your Mac's local Wi-Fi IP (e.g. `http://192.168.1.x:8000`) and run uvicorn with `--host 0.0.0.0 --port 8000`.

### 4. Build & Run on Device
1. Connect your iPhone via USB or Wi-Fi and select it as the run destination in Xcode.
2. Select the **`BoloSplit`** scheme and press **Cmd + R**.
3. If using a free Personal Team, trust your developer certificate on iPhone via **Settings → General → VPN & Device Management**.
4. Sign in with **Google** (or expand the **Developer Sign-In** section in `Debug` builds if your backend allows `X-User-Email` auth).
5. Grant **Microphone** permission when tapping **Bolo** for the first time.

### 5. Real-Device Test Checklist
Before capturing final screenshots and videos, verify these flows on iPhone:
- [ ] **Google Sign-In** & **Sign Out** confirmation flow
- [ ] **Voice Overlay (Audio):** Tap `Bolo`, speak a Hinglish/English expense, watch the live waveform, confirm ledger update + spoken TTS response
- [ ] **Voice Overlay (Ambiguity & Text Fallback):** Trigger clarification prompt and submit via keyboard
- [ ] **Friends & Settle Up:** Filter balances, open friend detail, settle balance, test undo
- [ ] **Groups:** Create/join a group, copy invite code, use `Bolo in Group`
- [ ] **Self & Activity:** Filter personal categories, search activity, swipe-to-delete with undo
- [ ] **Widget & Deep Link:** Add `Quick Bolo` widget to Home Screen / Lock Screen and tap it to verify direct launch into the listening overlay (`bolosplit://voice`)

In the iOS Simulator, you can also test the deep link directly via Terminal:
```bash
xcrun simctl openurl booted "bolosplit://voice"
```

---

## Running Unit Tests

Run `BoloSplitTests` in Xcode (`Cmd + U`) or from the terminal:

```bash
xcodebuild test \
  -project BoloSplit.xcodeproj \
  -scheme BoloSplit \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

*(Replace the destination device name with an installed simulator from `xcrun simctl list devices`.)*
