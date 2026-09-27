import SwiftUI

/// Core Tracing View supporting both "Draw with Camera" and "Draw with Screen" modes.
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

            // MARK: - Top Toast Alert
            if let toast = viewModel.toastMessage {
                VStack {
                    ToastView(message: toast)
                        .padding(.top, 56)
                    Spacer()
                }
            }

            // MARK: - Chrome & Controls Layer
            VStack {
                // Top Navigation Bar
                topNavigationBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer()

                // Floating Zoom & Lock Controls
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

            // App Brand Pill
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.65, green: 0.42, blue: 1.0))
                Text("TraceCam")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.45)))

            Spacer()

            // Info & Finish Buttons
            HStack(spacing: 12) {
                Button(action: {
                    HapticService.shared.selection()
                    viewModel.showInfoTips = true
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Info")
                            .font(.system(size: 11, weight: .medium))
                    }
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
                            .font(.system(size: 14))
                        Text("Finish")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color(red: 0.54, green: 0.28, blue: 0.98)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.45)))
        }
    }

    // MARK: - Floating Zoom & Lock Controls
    private var floatingAuxiliaryPills: some View {
        HStack {
            // Lock Pill (Left)
            Button(action: {
                viewModel.toggleLock()
            }) {
                Image(systemName: viewModel.isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.isLocked ? Color(red: 0.54, green: 0.28, blue: 0.98) : .white)
                    .padding(12)
                    .background(Circle().fill(Color.black.opacity(0.65)))
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }

            // Filter quick button
            Button(action: {
                HapticService.shared.selection()
                viewModel.showFilterSheet = true
            }) {
                Image(systemName: viewModel.selectedFilter == .original ? "wand.and.stars" : "wand.and.stars.inverse")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.selectedFilter != .original ? Color(red: 0.54, green: 0.28, blue: 0.98) : .white)
                    .padding(12)
                    .background(Circle().fill(Color.black.opacity(0.65)))
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }

            Spacer()

            // Undo / Redo controls
            if viewModel.canUndo || viewModel.canRedo {
                HStack(spacing: 8) {
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
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            // Camera Zoom Presets Pill (Right) - only in Camera mode
            if viewModel.mode == .camera {
                HStack(spacing: 4) {
                    ForEach([0.5, 1.0, 2.0], id: \.self) { zoom in
                        Button(action: {
                            viewModel.setCameraZoom(zoom)
                        }) {
                            Text(zoom == 0.5 ? "0,5 x" : (zoom == 1.0 ? "1,0 x" : "2,0 x"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(viewModel.selectedCameraZoom == zoom ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    viewModel.selectedCameraZoom == zoom ?
                                    Capsule().fill(Color.white.opacity(0.25)) :
                                    Capsule().fill(Color.clear)
                                )
                        }
                    }
                }
                .padding(4)
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Bottom Floating Toolbar
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

                // 3. Flashlight (or Grid in Screen mode)
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
                        icon: "grid",
                        title: "Guides",
                        isActive: viewModel.guideType != .none
                    ) {
                        cycleGuideType()
                    }
                }

                // 4. Hide / Show
                toolbarItem(
                    icon: viewModel.isHidden ? "eye" : "eye.slash",
                    title: viewModel.isHidden ? "Show" : "Hide",
                    isActive: viewModel.isHidden
                ) {
                    viewModel.toggleHidden()
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isActive ? Color(red: 0.54, green: 0.28, blue: 0.98) : .white.opacity(0.85))
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
