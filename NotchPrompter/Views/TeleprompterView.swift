import SwiftUI
import Cocoa

/// Static view for the concave corner fills, shown in a separate overlay window
/// so the curves remain fixed while the main panel bounces.
struct TopCurvesView: View {
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let r = cornerRadius
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                // Black fill from inner edges down — covers center strip + overshoot area
                Rectangle()
                    .fill(Color.black.opacity(0.95))
                    .frame(width: w - 2 * r, height: h)
                    .offset(x: r, y: 0)

                // Left concave corner fill
                Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: r, y: 0))
                    p.addLine(to: CGPoint(x: r, y: r))
                    p.addArc(center: CGPoint(x: 0, y: r),
                             radius: r,
                             startAngle: .degrees(0),
                             endAngle: .degrees(270),
                             clockwise: true)
                    p.closeSubpath()
                }
                .fill(Color.black.opacity(0.95))

                // Right concave corner fill
                Path { p in
                    p.move(to: CGPoint(x: w, y: 0))
                    p.addLine(to: CGPoint(x: w - r, y: 0))
                    p.addLine(to: CGPoint(x: w - r, y: r))
                    p.addArc(center: CGPoint(x: w, y: r),
                             radius: r,
                             startAngle: .degrees(180),
                             endAngle: .degrees(270),
                             clockwise: false)
                    p.closeSubpath()
                }
                .fill(Color.black.opacity(0.95))
            }
        }
    }
}

/// Shape that looks like a panel hanging from the bezel:
/// - Full window width at top (blends with bezel)
/// - Concave arcs transition from the wider top to narrower panel sides
///   The arcs curve inward, creating filled corner pieces that smoothly
///   connect the bezel edge to the panel sides
/// - Convex rounded corners at the bottom
/// The full shape with concave top corners — used only when panel is static (no animation)
struct PrompterShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        var p = Path()

        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))

        p.addArc(center: CGPoint(x: rect.width, y: r),
                 radius: r,
                 startAngle: .degrees(270),
                 endAngle: .degrees(180),
                 clockwise: true)

        p.addLine(to: CGPoint(x: rect.width - r, y: rect.height - r))

        p.addArc(center: CGPoint(x: rect.width - r - r, y: rect.height - r),
                 radius: r,
                 startAngle: .degrees(0),
                 endAngle: .degrees(90),
                 clockwise: false)

        p.addLine(to: CGPoint(x: r + r, y: rect.height))

        p.addArc(center: CGPoint(x: r + r, y: rect.height - r),
                 radius: r,
                 startAngle: .degrees(90),
                 endAngle: .degrees(180),
                 clockwise: false)

        p.addLine(to: CGPoint(x: r, y: r))

        p.addArc(center: CGPoint(x: 0, y: r),
                 radius: r,
                 startAngle: .degrees(0),
                 endAngle: .degrees(270),
                 clockwise: true)

        p.closeSubpath()
        return p
    }
}

/// Panel body shape — flat top, rounded bottom corners.
/// Used during animation so concave corners stay fixed in the curve overlay.
struct PanelBodyShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        var p = Path()

        // Flat top edge (inset by r on each side)
        p.move(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: rect.width - r, y: 0))

        // Right side
        p.addLine(to: CGPoint(x: rect.width - r, y: rect.height - r))

        // Bottom-right convex corner
        p.addArc(center: CGPoint(x: rect.width - r - r, y: rect.height - r),
                 radius: r,
                 startAngle: .degrees(0),
                 endAngle: .degrees(90),
                 clockwise: false)

        // Bottom edge
        p.addLine(to: CGPoint(x: r + r, y: rect.height))

        // Bottom-left convex corner
        p.addArc(center: CGPoint(x: r + r, y: rect.height - r),
                 radius: r,
                 startAngle: .degrees(90),
                 endAngle: .degrees(180),
                 clockwise: false)

        // Left side
        p.addLine(to: CGPoint(x: r, y: 0))

        p.closeSubpath()
        return p
    }
}

struct TeleprompterView: View {
    @ObservedObject var scrollEngine: ScrollEngine
    @ObservedObject var timerService: TimerService
    @ObservedObject var settings: AppSettings
    let text: String
    let showTimer: Bool
    let hasNotch: Bool

    private let cornerRadius: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Background — flat top, rounded bottom (concave corners are in the fixed overlay)
                PanelBodyShape(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.95))

                VStack(spacing: 0) {
                    // Top padding so first line starts lower
                    Spacer()
                        .frame(height: 36)

                    // Scrollable text area with top fade mask (only when scrolling)
                    ScrollableTextView(
                        text: text,
                        font: settings.nsFont(),
                        textColor: NSColor(settings.textColor),
                        lineSpacing: settings.textSize * 0.8,
                        scrollEngine: scrollEngine
                    )
                    .mask(
                        VStack(spacing: 0) {
                            if scrollEngine.scrollOffset > 1 {
                                LinearGradient(
                                    colors: [.clear, .white],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 30)
                            }

                            Color.white

                            // Bottom fade above timer/dot area
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 12)
                        }
                    )

                    Spacer()
                        .frame(height: 8)

                    // Timer or pulsing dot
                    if showTimer {
                        Text(timerService.formattedTime)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 8)
                    } else if scrollEngine.isActive {
                        PulsingDot()
                            .padding(.bottom, 10)
                    }
                }
                .padding(.horizontal, cornerRadius)
            }
        }
    }
}

struct PulsingDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
            .opacity(pulsing ? 0.3 : 0.8)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}
