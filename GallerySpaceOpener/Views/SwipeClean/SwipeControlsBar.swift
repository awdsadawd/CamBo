import SwiftUI

/// Bottom action bar providing tap buttons for Keep, Undo, and Delete.
public struct SwipeControlsBar: View {
    public let canUndo: Bool
    public let onKeep: () -> Void
    public let onUndo: () -> Void
    public let onDelete: () -> Void

    public init(
        canUndo: Bool,
        onKeep: @escaping () -> Void,
        onUndo: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.canUndo = canUndo
        self.onKeep = onKeep
        self.onUndo = onUndo
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 28) {
            // Left Swipe = KEEP (Green)
            Button(action: onKeep) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.18))
                            .frame(width: 64, height: 64)
                        Image(systemName: "checkmark")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.green)
                    }
                    Text("Keep (←)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }
            }

            // Center = UNDO
            Button(action: onUndo) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(canUndo ? 0.18 : 0.08))
                            .frame(width: 50, height: 50)
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(canUndo ? .yellow : .gray.opacity(0.4))
                    }
                    Text("Undo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(canUndo ? .yellow : .gray.opacity(0.4))
                }
            }
            .disabled(!canUndo)

            // Right Swipe = DELETE (Red)
            Button(action: onDelete) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.18))
                            .frame(width: 64, height: 64)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.red)
                    }
                    Text("Delete (→)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
