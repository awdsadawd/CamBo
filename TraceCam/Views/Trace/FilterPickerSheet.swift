import SwiftUI

/// Sheet for selecting trace image filters (Edge detection, Grayscale, Contrast, Comic/Line Art).
public struct FilterPickerSheet: View {
    @Binding var selectedFilter: TraceFilter
    public let onSelect: (TraceFilter) -> Void
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Select a filter to make faint lines and intricate details easier to trace over your paper.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                        ForEach(TraceFilter.allCases) { filter in
                            Button(action: {
                                selectedFilter = filter
                                HapticService.shared.selection()
                                onSelect(filter)
                                dismiss()
                            }) {
                                VStack(spacing: 10) {
                                    Image(systemName: filter.iconName)
                                        .font(.system(size: 26))
                                        .foregroundColor(selectedFilter == filter ? Color(red: 0.54, green: 0.28, blue: 0.98) : .primary)
                                        .frame(height: 36)

                                    Text(filter.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selectedFilter == filter ? Color(red: 0.54, green: 0.28, blue: 0.98) : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(selectedFilter == filter ? Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.12) : Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(selectedFilter == filter ? Color(red: 0.54, green: 0.28, blue: 0.98) : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Trace Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .fraction(0.6)])
        .presentationDragIndicator(.visible)
    }
}
