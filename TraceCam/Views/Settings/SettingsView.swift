import SwiftUI

/// Settings view for configuring defaults, haptics, and appearance.
public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var historyStore = ProjectHistoryStore.shared
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            Form {
                // Section: Tracing Defaults
                Section(header: Text("Tracing Defaults")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Opacity")
                            Spacer()
                            Text("\(Int(settings.defaultOpacity * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.defaultOpacity, in: 0.1...1.0, step: 0.05)
                            .tint(Color(red: 0.54, green: 0.28, blue: 0.98))
                    }

                    Picker("Default Camera Zoom", selection: $settings.defaultZoom) {
                        Text("0.5x (Ultra Wide)").tag(0.5)
                        Text("1.0x (Standard)").tag(1.0)
                        Text("2.0x (Telephoto)").tag(2.0)
                    }
                }

                // Section: Interaction & Feedback
                Section(header: Text("Feedback")) {
                    Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
                        .tint(Color(red: 0.54, green: 0.28, blue: 0.98))
                }

                // Section: Appearance
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $settings.appAppearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                // Section: Drawing Stats
                if !historyStore.recentProjects.isEmpty {
                    Section(header: Text("Your Drawing Stats")) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
                            Text("Total Drawing Time")
                            Spacer()
                            Text(historyStore.formattedTotalTime)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Image(systemName: "photo.stack")
                                .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
                            Text("Projects")
                            Spacer()
                            Text("\(historyStore.recentProjects.count)")
                                .foregroundColor(.secondary)
                        }

                        if let top = historyStore.mostUsedProject {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Most Drawn")
                                Spacer()
                                Text(top.formattedTimeSpent)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                // Section: Privacy & About
                Section(header: Text("About TraceCam")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.1.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("100% On-Device & Private")
                    }

                    Text("TraceCam processes all camera feeds, image cropping, and filters entirely on your device. No photos or drawings are ever transmitted to any external server.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Color(red: 0.54, green: 0.28, blue: 0.98))
                }
            }
        }
    }
}
