#if DEBUG
    import SwiftUI
    import UIKit

    /// Opt-in, read-only diagnostics for a demo app's real on-screen hierarchy.
    /// No UIKit view or controller configuration is changed by this probe.
    struct NativeLayoutProbe: UIViewRepresentable {
        func makeUIView(context _: Context) -> ProbeView {
            let view = ProbeView()
            view.isUserInteractionEnabled = false
            return view
        }

        func updateUIView(_ view: ProbeView, context _: Context) {
            view.scheduleCapture(reason: "update")
        }

        final class ProbeView: UIView {
            /// Fixed sample times, in seconds after the probe joins its window.
            /// Bounded on purpose: this records a launch timeline, not an ongoing poll.
            private static let sampleTimes: [Double] = [0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 5, 8]
            private static var timeline: [String] = []
            private static let processStart: Date? = {
                var info = kinfo_proc()
                var size = MemoryLayout<kinfo_proc>.stride
                var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
                guard sysctl(&name, u_int(name.count), &info, &size, nil, 0) == 0 else { return nil }
                let start = info.kp_proc.p_starttime
                return Date(timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000)
            }()

            private var captureScheduled = false
            private var lastCapture = ""
            private var scheduledSamples: Task<Void, Never>?

            override func didMoveToWindow() {
                super.didMoveToWindow()
                scheduleCapture(reason: "attached")
                scheduledSamples?.cancel()
                guard window != nil else { return }
                // UIKit settles some tab and split-view layout after the first
                // pass, so also read the hierarchy at fixed times. Never force a
                // layout pass or change the hierarchy to obtain a measurement.
                scheduledSamples = Task { @MainActor [weak self] in
                    let start = ContinuousClock.now
                    for time in Self.sampleTimes {
                        do {
                            try await Task.sleep(until: start + .seconds(time), clock: .continuous)
                        } catch {
                            return
                        }
                        self?.capture(reason: "scheduled")
                    }
                }
            }

            override func safeAreaInsetsDidChange() {
                super.safeAreaInsetsDidChange()
                scheduleCapture(reason: "safe-area")
            }

            override func layoutSubviews() {
                super.layoutSubviews()
                scheduleCapture(reason: "layout")
            }

            func scheduleCapture(reason: String) {
                guard !captureScheduled else { return }
                captureScheduled = true
                Task { @MainActor [weak self] in
                    await Task.yield()
                    guard let self else { return }
                    captureScheduled = false
                    capture(reason: reason)
                }
            }

            private func capture(reason: String) {
                guard let window, !window.isHidden,
                      let root = window.rootViewController else { return }

                Self.timeline.append(timelineEntry(window: window, root: root, reason: reason))
                Self.write(Self.timeline.joined(separator: "\n") + "\n", to: "layout-timeline.txt")

                var lines = [
                    "Window bounds: \(window.bounds)",
                    "Window safe insets: \(window.safeAreaInsets)",
                    "Arguments: \(ProcessInfo.processInfo.arguments.dropFirst())",
                    "Controllers:",
                ]

                func describeController(_ controller: UIViewController, depth: Int) {
                    let prefix = String(repeating: "  ", count: depth)
                    let view = controller.viewIfLoaded
                    let frame = view.map { String(describing: $0.convert($0.bounds, to: window)) } ?? "not loaded"
                    let insets = view.map { String(describing: $0.safeAreaInsets) } ?? "not loaded"
                    lines.append("\(prefix)\(type(of: controller)) frame=\(frame) safe=\(insets) additional=\(controller.additionalSafeAreaInsets)")
                    for child in controller.children {
                        describeController(child, depth: depth + 1)
                    }
                }

                func describeView(_ view: UIView, depth: Int) {
                    let prefix = String(repeating: "  ", count: depth)
                    let color = view.backgroundColor.map { String(describing: $0.resolvedColor(with: view.traitCollection).cgColor.components) } ?? "nil"
                    lines.append("\(prefix)\(type(of: view)) frame=\(view.convert(view.bounds, to: window)) safe=\(view.safeAreaInsets) background=\(color) hidden=\(view.isHidden) alpha=\(view.alpha) clips=\(view.clipsToBounds)")
                    for child in view.subviews {
                        describeView(child, depth: depth + 1)
                    }
                }

                describeController(root, depth: 0)
                lines.append("Views:")
                describeView(window, depth: 0)
                let text = lines.joined(separator: "\n")
                guard text != lastCapture else { return }
                lastCapture = text
                Self.write(text, to: "native-layout.txt")
            }

            /// One line per reading: time since process launch, the selected
            /// tab's top safe inset, every visible navigation bar's frame, and
            /// each large scroll view's vertical offset and adjusted top inset.
            private func timelineEntry(window: UIWindow, root: UIViewController, reason: String) -> String {
                let elapsed = Self.processStart.map { String(format: "%.3f", Date().timeIntervalSince($0)) } ?? "?"
                var tabContentTop = "none"
                if let content = Self.firstTabBarController(in: root)?.selectedViewController?.viewIfLoaded {
                    tabContentTop = "\(Double(content.safeAreaInsets.top))"
                }

                var bars: [String] = []
                var scrollViews: [String] = []
                func collect(in view: UIView) {
                    guard !view.isHidden, view.alpha > 0 else { return }
                    if let bar = view as? UINavigationBar {
                        let frame = bar.convert(bar.bounds, to: window)
                        bars.append("(\(Double(frame.minX)), \(Double(frame.minY)), \(Double(frame.width)), \(Double(frame.height)))")
                    }
                    // Large scroll views only: the Library list and detail content.
                    if let scroll = view as? UIScrollView, scroll.bounds.height > 200 {
                        let frame = scroll.convert(scroll.bounds, to: window)
                        scrollViews.append("x=\(Double(frame.minX)) w=\(Double(frame.width)) offsetY=\(Double(scroll.contentOffset.y)) insetTop=\(Double(scroll.adjustedContentInset.top))")
                    }
                    for child in view.subviews {
                        collect(in: child)
                    }
                }
                collect(in: window)

                let size = window.bounds.size
                return "t=\(elapsed)s reason=\(reason) window=\(Double(size.width))x\(Double(size.height)) windowTop=\(Double(window.safeAreaInsets.top)) tabContentTop=\(tabContentTop) navigationBars=[\(bars.joined(separator: ", "))] scrollViews=[\(scrollViews.joined(separator: "; "))]"
            }

            private static func firstTabBarController(in controller: UIViewController) -> UITabBarController? {
                if let tabs = controller as? UITabBarController { return tabs }
                for child in controller.children {
                    if let tabs = firstTabBarController(in: child) { return tabs }
                }
                return nil
            }

            private static func write(_ text: String, to filename: String) {
                do {
                    let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    try text.write(to: directory.appendingPathComponent(filename), atomically: true, encoding: .utf8)
                } catch {
                    print("Layout capture failed: \(error)")
                }
            }
        }
    }
#endif
