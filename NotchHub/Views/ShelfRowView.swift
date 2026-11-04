import SwiftUI

/// Row of parked files. Drag an item out to drop it anywhere (Finder copies it, the original
/// stays put); double-click opens it; × removes it from the shelf (the file isn't touched).
struct ShelfRowView: View {
    let shelf: ShelfStore
    let isTargeted: Bool

    /// Items that fit without scrolling; beyond this the row scrolls.
    private static let visibleCapacity = 6

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: NotchStyle.cornerRadius, style: .continuous)
        ZStack {
            shape.fill(isTargeted ? NotchStyle.fillStrong : NotchStyle.fill)
            if isTargeted {
                shape.strokeBorder(NotchStyle.tertiary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }

            if shelf.items.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Drop to add to shelf")
                        .font(NotchStyle.captionFont)
                }
                .foregroundStyle(NotchStyle.secondary)
            } else if shelf.items.count <= Self.visibleCapacity {
                items.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) { items }
            }
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    private var items: some View {
        HStack(spacing: 4) {
            ForEach(shelf.items) { item in
                ShelfItemView(item: item, shelf: shelf)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct ShelfItemView: View {
    let item: ShelfItem
    let shelf: ShelfStore

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: shelf.icon(for: item))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
            Text(item.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 56, height: 48)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { shelf.open(item) }
        .onDrag {
            let provider = NSItemProvider(object: item.url as NSURL)
            provider.suggestedName = item.url.lastPathComponent
            return provider
        } preview: {
            Image(nsImage: shelf.icon(for: item))
                .resizable()
                .frame(width: 48, height: 48)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                shelf.remove(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 6.5, weight: .heavy))
                    .foregroundStyle(NotchStyle.primary)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Color(white: 0.28)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Remove from shelf")
            .offset(x: -4, y: 1)
        }
    }
}
