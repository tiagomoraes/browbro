import SwiftUI
import AppKit

/// The cursor-anchored picker: a vibrancy popover with a slim URL header and a
/// flat, keyboard-first target list (browsers and Chrome profiles as peers).
struct PickerView: View {
    let model: PickerViewModel
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            UrlHeaderView(url: model.url, source: model.source)
            BBDivider(inset: 6)
                .padding(.vertical, 2)
            targetList
        }
        .padding(BB.padPopover)
        .frame(width: 360)
        .background(VisualEffectView(material: .popover))
        .clipShape(RoundedRectangle(cornerRadius: BB.radiusLG, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BB.radiusLG, style: .continuous)
                .strokeBorder(BB.popoverRing, lineWidth: BB.hairline))
        // Appears in ~120ms, opacity + scale from the cursor corner; never bouncy.
        .scaleEffect(appeared ? 1 : 0.965, anchor: .topLeading)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(BBMotion.easeOut(BBMotion.fast)) { appeared = true }
        }
    }

    @ViewBuilder private var targetList: some View {
        let rows = VStack(spacing: BB.gapRow) {
            ForEach(Array(model.targets.enumerated()), id: \.element.id) { index, target in
                TargetRowView(
                    target: target,
                    quickKey: index < 9 ? String(index + 1) : nil,
                    selected: index == model.selectedIndex,
                    onHoverSelect: { model.select(index) },
                    onTap: { model.commit(at: index) }
                )
                .id(index)
            }
        }

        if model.targets.count > 12 {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) { rows }
                    .frame(height: 460)
                    .onChange(of: model.selectedIndex) { _, index in
                        proxy.scrollTo(index)
                    }
            }
        } else {
            rows
        }
    }
}

/// The slim header: the link being routed — host emphasized, rest muted,
/// monospace for scannability — plus a best-effort "from {source app}" line.
struct UrlHeaderView: View {
    let url: URL
    let source: SourceApp?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            urlLine
                .lineLimit(1)
                .truncationMode(.tail)
            if let source {
                HStack(spacing: 4) {
                    if let icon = source.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 14, height: 14)
                    }
                    Text("from \(source.name)")
                        .font(BBFont.caption)
                        .foregroundStyle(BB.textSecondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(url.absoluteString)
    }

    private var urlLine: Text {
        let host = url.host ?? url.absoluteString
        var tail = url.path == "/" ? "" : url.path
        if let query = url.query { tail += "?" + query }
        if let fragment = url.fragment { tail += "#" + fragment }
        return Text(host)
            .font(BBFont.url)
            .fontWeight(.semibold)
            .foregroundStyle(BB.textPrimary)
        + Text(tail)
            .font(BBFont.url)
            .foregroundStyle(BB.textTertiary)
    }
}

/// A single target row: leading app icon or profile swatch, name, optional
/// detail, trailing quick-key badge. The highlight is a solid accent fill with
/// white text, exactly like a native menu selection; hover moves the highlight.
struct TargetRowView: View {
    let target: LaunchTarget
    let quickKey: String?
    let selected: Bool
    var onHoverSelect: () -> Void
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            leading
            VStack(alignment: .leading, spacing: 1) {
                Text(target.name)
                    .font(BBFont.row)
                    .foregroundStyle(selected ? BB.onAccent : BB.textPrimary)
                    .lineLimit(1)
                if let subtitle = target.subtitle {
                    Text(subtitle)
                        .font(BBFont.rowSub)
                        .foregroundStyle(selected ? Color.white.opacity(0.82) : BB.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let quickKey {
                KeyCap(text: quickKey, onAccent: selected)
            }
        }
        .padding(.horizontal, BB.padRowX)
        .padding(.vertical, BB.padRowY)
        .background(
            selected ? BB.accentFill : Color.clear,
            in: RoundedRectangle(cornerRadius: BB.radiusSM, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { inside in
            if inside { onHoverSelect() }
            (inside ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
        // Selection follows the keyboard/pointer in ~70ms.
        .animation(BBMotion.easeOut(BBMotion.instant), value: selected)
    }

    @ViewBuilder private var leading: some View {
        if case .chromeProfile = target.kind {
            ProfileSwatch(name: target.name, colorARGB: target.colorARGB)
        } else {
            AppIconChip(appURL: target.appURL)
        }
    }
}
