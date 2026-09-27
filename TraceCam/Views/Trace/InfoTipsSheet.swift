import SwiftUI

/// Educational walkthrough and tips modal for optimal tracing setup.
public struct InfoTipsSheet: View {
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to Trace Like a Pro")
                            .font(.title2.bold())
                        Text("Follow these practical tips to get crisp lines and avoid perspective distortion.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Tip 1: Camera Setup
                    TipCard(
                        number: "1",
                        icon: "camera.viewfinder",
                        title: "Prop Up Your Device",
                        description: "Place your phone on top of a tall clear drinking glass, a stack of books, or an adjustable tripod. Position your drawing pad directly beneath the camera lens."
                    )

                    // Tip 2: Lock the Overlay
                    TipCard(
                        number: "2",
                        icon: "lock.shield",
                        title: "Lock Your Overlay",
                        description: "Once your reference photo is positioned and scaled over your paper, tap the Lock button. This prevents accidental dragging while your hands are drawing."
                    )

                    // Tip 3: Lighting & Flashlight
                    TipCard(
                        number: "3",
                        icon: "flashlight.on.fill",
                        title: "Use Lighting & Torch",
                        description: "Good lighting creates high contrast between your pencil and the paper. Tap the Flashlight button in the bottom toolbar if you need extra illumination on your workspace."
                    )

                    // Tip 4: Filters
                    TipCard(
                        number: "4",
                        icon: "wand.and.stars",
                        title: "Use Edge Detection Filter",
                        description: "Switch to 'Outline (Edges)' or 'High Contrast' in the filter menu. It extracts the essential contours so your pencil has clear guides to follow."
                    )

                    // Tip 5: Screen Mode
                    TipCard(
                        number: "5",
                        icon: "ipad.and.iphone",
                        title: "Drawing Directly on Screen",
                        description: "In 'Draw with Screen' mode, place thin tracing or copy paper directly on your screen in a slightly dimmed room. The bright display illuminates lines right through the sheet."
                    )
                }
                .padding(20)
            }
            .navigationTitle("Tracing Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Color(red: 0.54, green: 0.28, blue: 0.98))
                }
            }
        }
    }
}

private struct TipCard: View {
    let number: String
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
