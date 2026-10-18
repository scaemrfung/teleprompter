import SwiftUI
import AppKit

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct HoverTracker: NSViewRepresentable {
    var onChange: (Bool) -> Void
    func makeNSView(context: Context) -> HoverTrackingView {
        let v = HoverTrackingView()
        v.onChange = onChange
        return v
    }
    func updateNSView(_ nsView: HoverTrackingView, context: Context) { nsView.onChange = onChange }
}

struct DragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView { DragHandleView() }
    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

struct ResizeGrip: NSViewRepresentable {
    var onResize: (NSSize) -> Void
    func makeNSView(context: Context) -> ResizeGripView {
        let v = ResizeGripView()
        v.onResize = onResize
        return v
    }
    func updateNSView(_ nsView: ResizeGripView, context: Context) { nsView.onResize = onResize }
}

struct PrompterView: View {
    @ObservedObject var model = PrompterModel.shared
    @ObservedObject var settings = Settings.shared
    var onResize: (NSSize) -> Void = { _ in }

    /// Where the reading line sits, as a fraction of the text area height.
    private let markerFraction: CGFloat = 0.3

    private var shape: some Shape {
        settings.floating
            ? AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            : AnyShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 22,
                                                                 bottomTrailing: 22, topTrailing: 0),
                                              style: .continuous))
    }

    var body: some View {
        VStack(spacing: 0) {
            if settings.floating {
                ZStack {
                    DragHandle()
                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 36, height: 4)
                        .allowsHitTesting(false)
                }
                .frame(height: 14)
            } else {
                Color.clear.frame(height: model.topInset)
            }
            textArea
        }
        .background(shape.fill(Color.black))
        .clipShape(shape)
        .overlay(alignment: .bottomTrailing) {
            if settings.floating {
                ResizeGrip(onResize: onResize).frame(width: 18, height: 18).padding(4)
            }
        }
        .background(HoverTracker { inside in model.hovering = inside })
    }

    private var textArea: some View {
        GeometryReader { geo in
            let markerY = geo.size.height * markerFraction
            ZStack(alignment: .top) {
                Text(model.text.isEmpty ? "Your script is empty. Open the editor from the menu bar to write one." : model.text)
                    .font(.system(size: settings.fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(settings.textColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(settings.fontSize * 0.25)
                    .frame(width: max(geo.size.width - 32, 50))
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
                    })
                    .padding(.top, markerY)
                    .offset(y: -model.offset)
                    .frame(width: geo.size.width, alignment: .top)
                    .scaleEffect(x: settings.mirror ? -1 : 1, y: 1)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            )
            .overlay(alignment: .topLeading) {
                // Reading marker
                HStack {
                    Image(systemName: "arrowtriangle.right.fill").font(.system(size: 9))
                    Spacer()
                    Image(systemName: "arrowtriangle.left.fill").font(.system(size: 9))
                }
                .foregroundStyle(Color.white.opacity(0.35))
                .padding(.horizontal, 4)
                .frame(width: geo.size.width)
                .offset(y: markerY + settings.fontSize * 0.6 - 5)
                .allowsHitTesting(false)
            }
            .overlay { countdownOverlay }
            .overlay(alignment: .bottom) { statusBar }
            .onPreferenceChange(ContentHeightKey.self) { h in model.contentHeight = h }
            .onAppear { model.viewportHeight = geo.size.height }
            .contentShape(Rectangle())
            .onTapGesture { model.togglePause() }
        }
    }

    @ViewBuilder private var countdownOverlay: some View {
        if model.countdownRemaining > 0 {
            ZStack {
                Color.black.opacity(0.75)
                Text("\(model.countdownRemaining)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
    }

    @ViewBuilder private var statusBar: some View {
        let label = statusText
        if !label.isEmpty {
            HStack(spacing: 6) {
                if settings.voiceMode {
                    Circle().fill(model.voice.speaking ? Color.green : Color.gray).frame(width: 7, height: 7)
                }
                Text(label)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.7))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .padding(.bottom, 6)
            .allowsHitTesting(false)
        }
    }

    private var statusText: String {
        if model.countdownRemaining > 0 { return "" }
        if model.finished { return "The end · press R to restart" }
        if !model.running {
            return model.offset == 0 ? "Press space or click to start" : "Paused · space to resume"
        }
        if model.heldByHover { return "Paused while the mouse is here" }
        if settings.voiceMode {
            if !model.voice.status.isEmpty && !model.voice.isListening { return model.voice.status }
            return model.voice.speaking ? "Listening" : "Waiting for your voice"
        }
        return ""
    }
}
