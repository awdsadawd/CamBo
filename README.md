# TraceCam 📷✨
**Native iOS Camera Drawing & Tracing Assistant in SwiftUI (iOS 16+)**

TraceCam transforms your iPhone or iPad into an augmented reality light-table and tracing projector. Prop your phone up over your sketchbook to trace through the live camera feed, or place tracing paper directly onto your screen.

---

## 🚀 How to Build & Install Without a Mac (GitHub Actions Plan)

Since you are running Windows 10 without a physical Mac, you can leverage **GitHub Actions** to build the complete native iOS `.ipa` binary on GitHub's macOS cloud runners for free.

### Step 1: Initialize Git & Push to GitHub from Windows

Open PowerShell or Command Prompt in the `TraceCam` folder:

```powershell
cd C:\Users\Administrator\.gemini\antigravity\scratch\TraceCam

# Initialize git repository
git init
git add .
git commit -m "Initial commit: TraceCam iOS app and CI/CD workflow"

# Rename default branch to main
git branch -M main

# Add your GitHub remote (Create a new private or public repository on github.com first)
git remote add origin https://github.com/YOUR_USERNAME/TraceCam.git

# Push to GitHub
git push -u origin main
```

### Step 2: GitHub Actions Automated Build

Once pushed:
1. Open your repository on **GitHub** in your web browser.
2. Click on the **Actions** tab at the top.
3. You will see the **"Build TraceCam iOS IPA"** workflow running automatically on a cloud Apple Silicon `macos-14` runner.
4. The workflow will:
   - Check out your repository.
   - Set up Xcode 15.4.
   - Archive the SwiftUI project (`TraceCam.xcodeproj`).
   - Package the `.app` bundle into a clean `.ipa` file (`Payload/TraceCam.app`).
   - Upload the artifact **`TraceCam-iOS-IPA`**.
5. Once the job completes (~2-3 minutes), click on the run and scroll to the **Artifacts** section at the bottom to download `TraceCam-iOS-IPA.zip`. Unzip it to get `TraceCam.ipa`.

---

## 📲 How to Install the .IPA on Your iPhone / iPad

Because you do not have a paid Apple Developer account ($99/yr), the `.ipa` produced by the GitHub workflow is unsigned. You can sign and install it onto your iPhone or iPad in 60 seconds using a free personal Apple ID:

### Option A: Using Sideloadly (Recommended on Windows)
1. Download **[Sideloadly](https://sideloadly.io/)** for Windows.
2. Install iTunes and iCloud for Windows (non-Microsoft Store versions as prompted by Sideloadly).
3. Connect your iPhone to your PC via USB cable.
4. Drag and drop `TraceCam.ipa` into Sideloadly.
5. Enter your personal Apple ID email and click **Start**.
6. On your iPhone, go to **Settings > General > VPN & Device Management**, tap your Apple ID, and tap **"Trust"**.
7. Open TraceCam!

### Option B: Using AltStore
1. Install **AltServer** on Windows from [altstore.io](https://altstore.io/).
2. Install the AltStore app onto your iPhone.
3. AirDrop or download `TraceCam.ipa` directly onto your iPhone (e.g., via Google Drive, iCloud, or browser) and open with AltStore.

### Optional: Upgrading to a Paid Apple Developer Account Later
If you purchase an Apple Developer Membership:
1. Export your Developer Certificate as a `.p12` file and download your Provisioning Profile.
2. Encode them to Base64:
   ```cmd
   certutil -encode developer_cert.p12 cert_base64.txt
   certutil -encode app.mobileprovision profile_base64.txt
   ```
3. Add `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, and `BUILD_PROVISION_PROFILE_BASE64` to **Repository Settings > Secrets and variables > Actions**.
4. Uncomment the signing block in `.github/workflows/build-ipa.yml`.

---

## 🎨 Features & Architecture

### Screen 1 — Home
- **Gallery Upload**: Opens `PhotosPicker` to choose any reference photo or sketch.
- **Take Photo**: Instant camera snapshot sheet to capture a reference directly.
- **Recent Projects**: Displays the last 5 tracing sessions with live thumbnails and timestamps. Tap any recent project to resume drawing immediately with your saved opacity and transforms.
- **Minimalist**: No stickers, no template catalog, no upsell cards.

### Screen 2 — Dedicated Crop & Align
- Interactive 4-corner draggable handles with real-time bounding box constraints.
- Pinch-to-zoom on the source image.
- 90° clockwise rotation button.
- Undo / Redo history stack.
- Reset button to restore full image bounds.
- Generates a cleanly trimmed `UIImage` before heading to the mode picker.

### Screen 3 — Drawing Mode Picker
Exactly two options:
1. **Draw with Camera** (Badge: *Popular*) — Prop your phone up with a tripod, books, or a drinking glass, and trace through the camera viewfinder.
2. **Draw with Screen** (Badge: *Easy*) — Place paper directly onto your phone screen to trace the glowing outlines.

### Screen 4 — Camera & Screen Trace View (Core Engine)
- **Live Camera Feed**: Smooth `AVCaptureSession` background with portrait orientation locking.
- **Signature Corner Brackets**: Vivid violet corner framing (`┌ ┐ └ ┘`) surrounding the reference image.
- **Interactive Gestures**: Simultaneous drag (reposition), pinch (scale), and rotation gestures.
- **Lock Overlay**: Dedicated lock pill button to freeze the overlay in place and prevent accidental dragging while drawing.
- **Camera Zoom Presets**: Floating pill selector (`0.5x | 1.0x | 2.0x`) for multi-camera lenses.
- **Frosted Glass Toolbar**:
  - **Opacity**: Opens an interactive popup slider with min/max icons.
  - **Flip**: Mirror horizontally.
  - **Flashlight**: Camera torch toggle.
  - **Hide/Show**: Quick glance toggle to inspect your drawing progress without moving the phone.
  - **Reset**: Return position, zoom, rotation, and opacity back to defaults.
- **Line Enhancement Filters (CoreImage)**:
  - B&W Grayscale
  - High Contrast
  - Outline (Sobel Edge Detection)
  - Pencil Sketch / Comic Line Art
- **Symmetry & Composition Guides**:
  - Rule of Thirds
  - 3x3 Fine Grid
  - Center Crosshair
- **Finish & Save**:
  - Renders a composite capture merging your real drawing pad and overlay.
  - One-tap "Save to Photos Library" with feedback.
  - Native iOS Share Sheet.

---

## 📂 Project Structure

```
TraceCam/
├── .github/
│   └── workflows/
│       └── build-ipa.yml          # Cloud macOS runner workflow to produce .ipa
├── TraceCam/
│   ├── App/
│   │   └── TraceCamApp.swift      # SwiftUI @main entry point & theme management
│   ├── Models/
│   │   ├── DrawingMode.swift      # Camera Trace vs Screen Trace
│   │   ├── TraceFilter.swift      # CoreImage filters (Edge, Grayscale, Comic)
│   │   ├── GuideOverlayType.swift # Grid & crosshair types
│   │   ├── TraceOverlayState.swift# Transform state for undo/redo & persistence
│   │   └── ProjectItem.swift      # Recent project metadata
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift    # Image selection & navigation flow
│   │   ├── CropViewModel.swift    # 4-corner crop math & undo/redo
│   │   ├── TraceViewModel.swift   # Gesture transformations, filters, export
│   │   ├── ProjectHistoryStore.swift # Local disk storage for recent 5 sessions
│   │   └── AppSettings.swift      # User defaults (opacity, zoom, haptics)
│   ├── Services/
│   │   ├── CameraService.swift    # AVFoundation camera session, torch, zoom
│   │   ├── ImageFilterService.swift # CoreImage processing pipeline
│   │   └── HapticService.swift    # Tactile feedback generator
│   ├── Views/
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── RecentProjectsView.swift
│   │   │   └── CameraCapturePickerView.swift
│   │   ├── Crop/
│   │   │   └── CropView.swift
│   │   ├── ModePicker/
│   │   │   └── ModePickerView.swift
│   │   ├── Trace/
│   │   │   ├── CameraTraceView.swift
│   │   │   ├── CameraPreviewView.swift
│   │   │   ├── TraceOverlayContainerView.swift
│   │   │   ├── CornerBracketsView.swift
│   │   │   ├── GuideGridView.swift
│   │   │   ├── OpacityPopupView.swift
│   │   │   ├── FilterPickerSheet.swift
│   │   │   ├── InfoTipsSheet.swift
│   │   │   └── FinishExportSheet.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   └── Components/
│   │       └── GlassCard.swift
│   └── Resources/
│       ├── Info.plist             # Camera & Photo Library permission descriptions
│       └── Assets.xcassets/       # AppIcon, AccentColor, Launch configuration
├── TraceCam.xcodeproj/            # Complete Xcode project with shared scheme
└── README.md
```

---

## 🔒 Privacy & Permissions
- **Camera (`NSCameraUsageDescription`)**: Used solely for the live tracing background. No video is recorded or streamed.
- **Photos (`NSPhotoLibraryUsageDescription` & `NSPhotoLibraryAddUsageDescription`)**: Used to import reference images and save finished artwork to your camera roll.
- **100% On-Device**: Zero third-party network SDKs, analytics, or external servers.
