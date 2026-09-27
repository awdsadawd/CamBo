import SwiftUI

/// Core Tracing View supporting both "Draw with Camera" and "Draw with Screen" modes.
/// Updated: 3-state hide cycle, proper lens zoom presets, drawing timer, long-press peek, guide grid in all modes.
public struct CameraTraceView: View {
    @StateObject var viewModel: TraceViewModel
    @Environment(\.dismiss) private var dismiss
    public let onReturnHome: () -> Void

    public init(
        image: UIImage,
        mode: DrawingMode = .camera,
        initialState: TraceOverlayState? = nil,
        existingProjectId: UUID? = nil,
        onReturnHome: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: TraceViewModel(
            image: image,
            mode: mode,
            initialState: initialState,
            existingProjectId: existingProjectId
        ))
        self.onReturnHome = onReturnHome
    }

    public var body: some View {
        ZStack {
            // MARK: - Background Layer
            if viewModel.mode == .camera {
                CameraPreviewView(cameraService: viewModel.cameraService)
                    .ignoresSafeArea()
            } else {
                Color.white
                    .ignoresSafeArea()
            }

            // MARK: - Interactive Overlay Layer
            TraceOverlayContainerView(viewModel: viewModel)

            // MARK: - Immersive mode: tap anywhere to restore UI
            if viewModel.visibility == .allHidden {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.cycleVisibility()
                    }
            }

            // MARK: - Top Toast Alert
            if let toast = viewModel.toastMessage {
                VStack {
                    ToastView(message: toast)
                        .padding(.top, 56)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // MARK: - Chrome & Controls (hidden in immersive mode)
            if viewModel.isUIVisible {
                VStack(spacing: 0) {
                    // Top Navigation Bar
                    topNavigationBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer()

                    // Floating Zoom, Lock, Filter, Undo/Redo Controls
                    floatingAuxiliaryPills
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    // Opacity Popup (Shown above toolbar when toggled)
                    if viewModel.showOpacitySlider {
                        OpacityPopupView(opacity: $viewModel.opacity) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.showOpacitySlider = false
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 10)
                    }

                    // Bottom Floating Toolbar
                    bottomToolbar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        // Sheets & Alerts
        .sheet(isPresented: $viewModel.showInfoTips) {
            InfoTipsSheet()
        }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            FilterPickerSheet(selectedFilter: $viewModel.selectedFilter) { _ in }
        }
        .sheet(isPresented: $viewModel.showFinishExport) {
            FinishExportSheet(viewModel: viewModel, onReturnHome: onReturnHome)
        }
        .alert("Exit Tracing?", isPresented: $viewModel.showExitConfirmation) {
            Button("Keep Tracing", role: .cancel) {}
            Button("Save & Exit", role: .destructive) {
                viewModel.autoSaveToRecent()
                onReturnHome()
            }
        } message: {
            Text("Your current alignment will be saved to Recent Projects so you can resume drawing at any time.")
        }
    }

    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack {
            // Close Button
            Button(action: {
                HapticService.shared.impact(.light)
                viewModel.showExitConfirmation = true
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.45)))
            }

            Spacer()

            // Center Pill: App brand + live session timer
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.65, green: 0.42, blue: 1.0))
                Text("TraceCam")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: 14)

                // Drawing Session Timer
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                Text(viewModel.formattedElapsed)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.45)))

            Spacer()

            // Info & Finish Buttons
            HStack(spacing: 10) {
                Button(action: {
                    HapticService.shared.selection()
                    viewModel.showInfoTips = true
                }) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                Button(action: {
                    HapticService.shared.impact(.medium)
                    Task {
                        await viewModel.prepareFinish()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 13))
                        Text("Finish")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color(red: 0.54, green: 0.28, blue: 0.98)))
                }
            }
        }
    }

    // MARK: - Floating Auxiliary Pills (Zoom, Lock, Filter, Guides, Undo/Redo)
    private var floatingAuxiliaryPills: some View {
        HStack {
            // Lock + Filter + Guide Buttons (Left cluster)
            HStack(spacing: 8) {
                // Lock Pill
                Button(action: {
                    viewModel.toggleLock()
                }) {
                    Image(systemName: viewModel.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.isLocked ? Color(red: 0.54, green: 0.28, blue: 0.98) : .white)
                        .padding(11)
                        .background(Circle().fill(Color.black.opacity(0.65)))
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }

                // Filter Toggle
                Button(action: {
                    HapticService.shared.selection()
                    viewModel.showFilterSheet = true
                }) {
                    Image(systemName: viewModel.selectedFilter == .original ? "wand.and.stars" : "wand.and.stars.inverse")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.selectedFilter != .original ? Color(red: 0.54, green: 0.28, blue: 0.98) : .white)
                        .padding(11)
                        .background(Circle().fill(Color.black.opacity(0.65)))
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }

                // Symmetry/Grid Guide (cycle through types — available in BOTH modes)
                Button(action: {
                    cycleGuideType()
                }) {
                    Image(systemName: viewModel.guideType.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.guideType != .none ? Color(red: 0.54, green: 0.28, blue: 0.98) : .white)
                        .padding(11)
                        .background(Circle().fill(Color.black.opacity(0.65)))
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
            }

            Spacer()

            // Undo / Redo (shown when available)
            if viewModel.canUndo || viewModel.canRedo {
                HStack(spacing: 6) {
                    Button(action: { viewModel.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(viewModel.canUndo ? .white : .white.opacity(0.3))
                            .padding(8)
                    }
                    .disabled(!viewModel.canUndo)

                    Button(action: { viewModel.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(viewModel.canRedo ? .white : .white.opacity(0.3))
                            .padding(8)
                    }
                    .disabled(!viewModel.canRedo)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            // Camera Zoom Presets Pill (Right) — dynamically built from hardware
            if viewModel.mode == .camera {
                HStack(spacing: 3) {
                    ForEach(viewModel.cameraService.zoomPresets) { preset in
                        Button(action: {
                            viewModel.selectZoomPreset(preset)
                        }) {
                            Text(preset.label)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(viewModel.cameraService.activePreset == preset ? .white : .white.opacity(0.55))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    viewModel.cameraService.activePreset == preset ?
                                    Capsule().fill(Color.white.opacity(0.25)) :
                                    Capsule().fill(Color.clear)
                                )
                        }
                    }
                }
                .padding(4)
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
        }
    }

    // MARK: - Bottom Floating Toolbar (5 buttons)
    private var bottomToolbar: some View {
        GlassCard(cornerRadius: 26, backgroundColor: Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.92)) {
            HStack(spacing: 0) {
                // 1. Opacity
                toolbarItem(
                    icon: "circle.lefthalf.filled",
                    title: "Opacity",
                    isActive: viewModel.showOpacitySlider
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.showOpacitySlider.toggle()
                    }
                }

                // 2. Flip
                toolbarItem(
                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    title: "Flip",
                    isActive: viewModel.isFlipped
                ) {
                    viewModel.toggleFlip()
                }

                // 3. Flashlight (Camera mode) / Brightness indicator (Screen mode)
                if viewModel.mode == .camera {
                    toolbarItem(
                        icon: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                        title: "Flashlight",
                        isActive: viewModel.isTorchOn
                    ) {
                        viewModel.toggleTorch()
                    }
                } else {
                    toolbarItem(
                        icon: "sun.max.fill",
                        title: "Max Light",
                        isActive: true
                    ) {
                        // Screen mode auto-maxes brightness on appear.
                        // Tapping this confirms it and shows a toast.
                        UIScreen.main.brightness = 1.0
                        viewModel.showToast("Screen Brightness: Maximum")
                    }
                }

                // 4. Hide / Show — 3-state cycle
                toolbarItem(
                    icon: viewModel.visibility.hideButtonIcon,
                    title: viewModel.visibility.hideButtonLabel,
                    isActive: viewModel.visibility != .allVisible
                ) {
                    viewModel.cycleVisibility()
                }

                // 5. Reset
                toolbarItem(
                    icon: "arrow.counterclockwise",
                    title: "Reset",
                    isActive: false
                ) {
                    viewModel.resetTransform()
                }
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: 440)
    }

    private func toolbarItem(
        icon: String,
        title: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticService.shared.selection()
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isActive ? Color(red: 0.54, green: 0.28, blue: 0.98) : .white)
                    .frame(height: 24)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isActive ? Color(red: 0.54, green: 0.28, blue: 0.98) : .white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func cycleGuideType() {
        switch viewModel.guideType {
        case .none:
            viewModel.guideType = .ruleOfThirds
            viewModel.showToast("Rule of Thirds Guide")
        case .ruleOfThirds:
            viewModel.guideType = .grid3x3
            viewModel.showToast("Fine Grid Guide")
        case .grid3x3:
            viewModel.guideType = .crosshair
            viewModel.showToast("Center Crosshair Guide")
        case .crosshair:
            viewModel.guideType = .none
            viewModel.showToast("Guides Off")
        }
        HapticService.shared.selection()
    }
}
