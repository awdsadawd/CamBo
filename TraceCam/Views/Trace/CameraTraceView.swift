import SwiftUI

/// Core Tracing View — Camera and Screen modes.
/// Guides removed. Lock hides brackets. Screen stays awake. Re-crop sheet. Session timer.
public struct CameraTraceView: View {
    @StateObject var viewModel: TraceViewModel
    @Environment(\.dismiss) private var dismiss
    public let onReturnHome: () -> Void

    public init(
        image: UIImage,
        originalImage: UIImage? = nil,
        mode: DrawingMode = .camera,
        initialState: TraceOverlayState? = nil,
        existingProjectId: UUID? = nil,
        onReturnHome: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: TraceViewModel(
            image: image,
            originalImage: originalImage,
            mode: mode,
            initialState: initialState,
            existingProjectId: existingProjectId
        ))
        self.onReturnHome = onReturnHome
    }

    public var body: some View {
        ZStack {
            // MARK: - Background
            if viewModel.mode == .camera {
                CameraPreviewView(cameraService: viewModel.cameraService)
                    .ignoresSafeArea()
            } else {
                Color.white.ignoresSafeArea()
            }

            // MARK: - Overlay
            TraceOverlayContainerView(viewModel: viewModel)

            // MARK: - Immersive tap target (Tap anywhere to restore UI)
            if !viewModel.isUIVisible {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.cycleVisibility()
                        }
                    }
            }

            // MARK: - Toast
            if let toast = viewModel.toastMessage {
                VStack {
                    ToastView(message: toast).padding(.top, 56)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // MARK: - UI Chrome (hidden in immersive)
            if viewModel.isUIVisible {
                VStack(spacing: 0) {
                    topNavigationBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer()

                    floatingAuxiliaryPills
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    if viewModel.showOpacitySlider {
                        OpacityPopupView(opacity: $viewModel.opacity) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.showOpacitySlider = false
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 10)
                    }

                    bottomToolbar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $viewModel.showInfoTips) { InfoTipsSheet() }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            FilterPickerSheet(selectedFilter: $viewModel.selectedFilter) { _ in }
        }
        .sheet(isPresented: $viewModel.showFinishExport) {
            FinishExportSheet(viewModel: viewModel, onReturnHome: onReturnHome)
        }
        .sheet(isPresented: $viewModel.showRecropSheet) {
            RecropSheetView(sourceImage: viewModel.originalUncroppedImage) { newImage in
                viewModel.updateSourceImage(newImage)
            }
        }
        .alert("Exit Tracing?", isPresented: $viewModel.showExitConfirmation) {
            Button("Keep Tracing", role: .cancel) {}
            Button("Save & Exit", role: .destructive) {
                viewModel.autoSaveToRecent()
                onReturnHome()
            }
        } message: {
            Text("Your alignment and \(viewModel.formattedElapsed) of drawing time will be saved.")
        }
    }

    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack {
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

            // Brand + Timer
            HStack(spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("TraceCam")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Rectangle().fill(Color.white.opacity(0.3)).frame(width: 1, height: 14)

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

            // Re-crop, Info, Finish
            HStack(spacing: 8) {
                // Re-crop button
                Button(action: {
                    HapticService.shared.selection()
                    viewModel.showRecropSheet = true
                }) {
                    Image(systemName: "crop")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                Button(action: {
                    HapticService.shared.selection()
                    viewModel.showInfoTips = true
                }) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                Button(action: {
                    HapticService.shared.impact(.medium)
                    Task { await viewModel.prepareFinish() }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "flag.fill").font(.system(size: 13))
                        Text("Finish").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color(red: 0.54, green: 0.28, blue: 0.98)))
                }
            }
        }
    }

    // MARK: - Floating Aux (Lock, Filter, Undo/Redo, Zoom)
    private var floatingAuxiliaryPills: some View {
        HStack {
            HStack(spacing: 8) {
                // Lock (hides brackets when active)
                Button(action: { viewModel.toggleLock() }) {
                    Image(systemName: viewModel.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.isLocked ? Color(red: 0.54, green: 0.28, blue: 0.98) : .white)
                        .padding(11)
                        .background(Circle().fill(Color.black.opacity(0.65)))
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }

                // Filter
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
            }

            Spacer()

            // Undo/Redo
            if viewModel.canUndo || viewModel.canRedo {
                HStack(spacing: 6) {
                    Button(action: { viewModel.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(viewModel.canUndo ? .white : .white.opacity(0.3))
                            .padding(8)
                    }.disabled(!viewModel.canUndo)

                    Button(action: { viewModel.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(viewModel.canRedo ? .white : .white.opacity(0.3))
                            .padding(8)
                    }.disabled(!viewModel.canRedo)
                }
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            // Camera Zoom (hardware-mapped)
            if viewModel.mode == .camera {
                HStack(spacing: 3) {
                    ForEach(viewModel.cameraService.zoomPresets) { preset in
                        Button(action: { viewModel.selectZoomPreset(preset) }) {
                            Text(preset.label)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(viewModel.cameraService.activePreset == preset ? .white : .white.opacity(0.55))
                                .padding(.horizontal, 9).padding(.vertical, 6)
                                .background(
                                    viewModel.cameraService.activePreset == preset ?
                                    Capsule().fill(Color.white.opacity(0.25)) : Capsule().fill(Color.clear)
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

    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        GlassCard(cornerRadius: 26, backgroundColor: Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.92)) {
            HStack(spacing: 0) {
                toolbarItem(icon: "circle.lefthalf.filled", title: "Opacity", isActive: viewModel.showOpacitySlider) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.showOpacitySlider.toggle()
                    }
                }

                toolbarItem(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", title: "Flip", isActive: viewModel.isFlipped) {
                    viewModel.toggleFlip()
                }

                if viewModel.mode == .camera {
                    toolbarItem(icon: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill", title: "Flashlight", isActive: viewModel.isTorchOn) {
                        viewModel.toggleTorch()
                    }
                } else {
                    toolbarItem(icon: "sun.max.fill", title: "Max Light", isActive: true) {
                        UIScreen.main.brightness = 1.0
                        viewModel.showToast("Screen Brightness: Maximum")
                    }
                }

                toolbarItem(icon: viewModel.visibility.hideButtonIcon, title: viewModel.visibility.hideButtonLabel, isActive: viewModel.visibility != .allVisible) {
                    viewModel.cycleVisibility()
                }

                toolbarItem(icon: "arrow.counterclockwise", title: "Reset", isActive: false) {
                    viewModel.resetTransform()
                }
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: 440)
    }

    private func toolbarItem(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
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
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Re-crop Sheet

/// Presents the current traced image in a crop interface for further trimming.
struct RecropSheetView: View {
    let sourceImage: UIImage
    let onCropped: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cropVM: CropViewModel

    init(sourceImage: UIImage, onCropped: @escaping (UIImage) -> Void) {
        self.sourceImage = sourceImage
        self.onCropped = onCropped
        _cropVM = StateObject(wrappedValue: CropViewModel(sourceImage: sourceImage))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    HStack(spacing: 12) {
                        Button(action: { cropVM.undo() }) {
                            Image(systemName: "arrow.uturn.backward").font(.system(size: 16, weight: .semibold))
                        }.disabled(!cropVM.canUndo)
                        Button(action: { cropVM.redo() }) {
                            Image(systemName: "arrow.uturn.forward").font(.system(size: 16, weight: .semibold))
                        }.disabled(!cropVM.canRedo)
                    }.foregroundColor(.primary)

                    Spacer()

                    HStack(spacing: 16) {
                        Button(action: { cropVM.rotate90() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "rotate.right")
                                Text("Rotate").font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        Button(action: { cropVM.reset() }) {
                            Text("Reset").font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 10)

                // Crop Canvas
                GeometryReader { geo in
                    ZStack {
                        Color.black.opacity(0.92)
                        Image(uiImage: cropVM.sourceImage)
                            .resizable().scaledToFit()
                            .rotationEffect(.degrees(Double(cropVM.rotationDegrees)))
                            .scaleEffect(cropVM.zoomScale)
                            .frame(width: geo.size.width, height: geo.size.height)

                        StableCropBoxView(
                            cropRect: $cropVM.cropRect,
                            containerSize: CGSize(width: geo.size.width, height: geo.size.height),
                            onCommit: { cropVM.recordHistory() }
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)

                // Confirm
                Button(action: {
                    HapticService.shared.impact(.medium)
                    let cropped = cropVM.produceCroppedImage()
                    onCropped(cropped)
                    dismiss()
                }) {
                    Text("Apply Re-crop")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Color(red: 0.54, green: 0.28, blue: 0.98))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .navigationTitle("Re-crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
