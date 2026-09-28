import SwiftUI
import PhotosUI

/// Screen 1: Minimalist Home screen with Gallery picker card, Camera capture card, and Recent Projects row.
public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var navigationPath = NavigationPath()

    public init() {}

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Bar
                    headerBar
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                    // Hero Cards Grid (Gallery & Camera)
                    VStack(spacing: 16) {
                        // 1. Primary Card: Gallery Upload
                        PhotosPicker(selection: $viewModel.selectedPickerItem, matching: .images) {
                            galleryUploadCard
                        }
                        .buttonStyle(.plain)

                        // 2. Secondary Card: Take Photo
                        Button(action: {
                            HapticService.shared.impact(.light)
                            viewModel.showCameraCaptureSheet = true
                        }) {
                            takePhotoCard
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    // Recent Projects Row (Last 5 sessions)
                    RecentProjectsView(
                        onSelect: { project in
                            viewModel.resumeProject(project)
                        },
                        onRecrop: { project in
                            viewModel.recropProject(project)
                        }
                    )
                    .padding(.top, 8)

                    Spacer(minLength: 30)
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.showCameraCaptureSheet) {
                CameraCapturePickerView { captured in
                    viewModel.handleCapturedPhoto(captured)
                }
            }
            .sheet(isPresented: $viewModel.showSettingsSheet) {
                SettingsView()
            }
            // Navigation destination for Cropping
            .navigationDestination(isPresented: $viewModel.shouldNavigateToCrop) {
                if let picked = viewModel.pickedImage {
                    CropView(
                        originalImage: picked,
                        existingProjectId: viewModel.resumedProject?.id
                    ) {
                        viewModel.shouldNavigateToCrop = false
                        viewModel.pickedImage = nil
                        viewModel.resumedProject = nil
                        navigationPath = NavigationPath()
                    }
                }
            }
            // Navigation destination for Resuming Recent Project directly
            .navigationDestination(isPresented: Binding(
                get: { viewModel.resumedProject != nil && !viewModel.shouldNavigateToCrop },
                set: { if !$0 { viewModel.resumedProject = nil } }
            )) {
                if let project = viewModel.resumedProject,
                   let cropped = viewModel.croppedImage {
                    CameraTraceView(
                        image: cropped,
                        originalImage: viewModel.pickedImage,
                        mode: project.mode,
                        initialState: project.overlayState,
                        existingProjectId: project.id,
                        onReturnHome: {
                            viewModel.resumedProject = nil
                            viewModel.croppedImage = nil
                            viewModel.pickedImage = nil
                            navigationPath = NavigationPath()
                        }
                    )
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            HStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.35), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text("TraceCam")
                        .font(.system(size: 22, weight: .bold))
                    Text("Tracing & Drawing Assistant")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                HapticService.shared.selection()
                viewModel.showSettingsSheet = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
            }
        }
    }

    // MARK: - Gallery Upload Card (Adaptive Dark/Light Mode Theme)
    private var galleryUploadCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.16))
                    .frame(width: 54, height: 54)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Gallery")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
                }

                Text("Upload your image to trace")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    Color(uiColor: UIColor { traits in
                        traits.userInterfaceStyle == .dark
                            ? UIColor(red: 0.15, green: 0.12, blue: 0.22, alpha: 1.0)
                            : UIColor(red: 0.95, green: 0.93, blue: 1.0, alpha: 1.0)
                    })
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: - Take Photo Card (Viewfinder Cyan Theme)
    private var takePhotoCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.0, green: 0.78, blue: 0.88).opacity(0.16))
                    .frame(width: 54, height: 54)

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.78, blue: 0.88))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Take Photo")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.78, blue: 0.88))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.78, blue: 0.88))
                }

                Text("Snap a fresh reference with camera")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    Color(uiColor: UIColor { traits in
                        traits.userInterfaceStyle == .dark
                            ? UIColor(red: 0.11, green: 0.15, blue: 0.18, alpha: 1.0)
                            : UIColor(red: 0.93, green: 0.97, blue: 0.99, alpha: 1.0)
                    })
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 0.0, green: 0.78, blue: 0.88).opacity(0.28), lineWidth: 1)
        )
    }
}
