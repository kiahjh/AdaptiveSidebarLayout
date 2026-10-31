import SwiftUI
import UIKit

private enum CanvasMode: String, CaseIterable, Identifiable {
    case respect = "Respect safe area"
    case ignore = "Ignore safe area"

    var id: Self { self }
}

private struct CanvasGeometry: Equatable {
    let frame: CGRect
    let insets: EdgeInsets

    init(_ geometry: GeometryProxy) {
        frame = geometry.frame(in: .global)
        insets = geometry.safeAreaInsets
    }
}

struct SafeAreaExplorerView: View {
    @State private var mode = ProcessInfo.processInfo.arguments.contains("--ignore-safe-area")
        ? CanvasMode.ignore : CanvasMode.respect
    @State private var showBoundary = true
    @State private var showDetails = false
    @State private var canvasGeometry: CanvasGeometry?
    @State private var windowMetrics: ExplorerWindowMetrics?

    private let pink = Color(red: 1, green: 0, blue: 0.55)
    private let cyan = Color(red: 0, green: 0.9, blue: 1)

    var body: some View {
        // This reader stays outside ignoresSafeArea so it always measures the
        // original root proposal. Only the pink test rectangle changes modes.
        GeometryReader { root in
            ZStack {
                Rectangle()
                    .fill(pink)
                    .onGeometryChange(for: CanvasGeometry.self) { geometry in
                        CanvasGeometry(geometry)
                    } action: { geometry in
                        canvasGeometry = geometry
                    }
                    .ignoresSafeArea(.container, edges: mode == .ignore ? .all : [])

                if showBoundary {
                    Rectangle()
                        .strokeBorder(.yellow, lineWidth: 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .background {
                Rectangle()
                    .fill(cyan)
                    .ignoresSafeArea(.container)
            }
            .background {
                ExplorerWindowProbe { metrics in
                    windowMetrics = metrics
                }
            }
            .overlay(alignment: .bottom) {
                inspector(root: CanvasGeometry(root))
                    .frame(maxWidth: 540)
                    .frame(maxHeight: max(0, min(480, root.size.height - 32)))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(16)
            }
        }
    }

    private func inspector(root: CanvasGeometry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Safe Area Explorer")
                        .font(.headline)
                    Spacer()
                    Text("iOS \(UIDevice.current.systemVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Pink canvas behavior", selection: $mode) {
                    ForEach(CanvasMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(mode == .respect ? "Rectangle: no safe-area override" : "Rectangle: .ignoresSafeArea(.container)")
                    .font(.caption.monospaced())

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        legend("Pink: test rectangle", color: pink)
                        legend("Cyan: extended background", color: cyan)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        legend("Pink: test rectangle", color: pink)
                        legend("Cyan: extended background", color: cyan)
                    }
                }

                Divider()

                metric("Root SwiftUI safe insets", value: describe(root.insets))
                if let canvasGeometry {
                    metric("Pink rectangle safe insets", value: describe(canvasGeometry.insets))
                    metric("Pink rectangle frame (SwiftUI global)", value: describe(canvasGeometry.frame))
                }
                if let windowMetrics {
                    metric("UIWindow safe insets", value: describe(windowMetrics.windowInsets))
                } else {
                    Text("Waiting for a visible UIWindow…")
                        .font(.caption)
                }

                DisclosureGroup("More measurements", isExpanded: $showDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        metric("Root SwiftUI frame (global)", value: describe(root.frame))
                        if let windowMetrics {
                            metric("UIWindow bounds", value: describe(windowMetrics.windowBounds))
                            metric("Root controller view frame (in window)", value: describe(windowMetrics.rootFrame))
                            metric("Root controller safe insets", value: describe(windowMetrics.rootInsets))
                            metric("Root controller additional insets", value: describe(windowMetrics.additionalInsets))
                        }
                        Text("All measurements are in points. T/L/B/R means top/left/bottom/right; SwiftUI uses leading/trailing for L/R.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                .font(.subheadline)

                Toggle("Yellow outline: original safe-content bounds", isOn: $showBoundary)
                    .font(.caption)

                Text("Move the window away from the display’s top, move it back, then try full screen. Compare both modes in each position. Controls always respect the safe area.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func describe(_ insets: EdgeInsets) -> String {
        "T \(points(insets.top)) · L \(points(insets.leading)) · B \(points(insets.bottom)) · R \(points(insets.trailing))"
    }

    private func describe(_ insets: UIEdgeInsets) -> String {
        "T \(points(insets.top)) · L \(points(insets.left)) · B \(points(insets.bottom)) · R \(points(insets.right))"
    }

    private func describe(_ rect: CGRect) -> String {
        "x \(points(rect.minX)) · y \(points(rect.minY)) · w \(points(rect.width)) · h \(points(rect.height))"
    }

    private func points(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }
}

#Preview {
    SafeAreaExplorerView()
}
