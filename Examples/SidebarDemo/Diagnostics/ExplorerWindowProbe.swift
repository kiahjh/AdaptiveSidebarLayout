import SwiftUI
import UIKit

struct ExplorerWindowMetrics: Equatable {
    let windowBounds: CGRect
    let windowInsets: UIEdgeInsets
    let rootFrame: CGRect
    let rootInsets: UIEdgeInsets
    let additionalInsets: UIEdgeInsets
}

/// Read-only instrumentation attached to this scene's actual window. It does not
/// change window backgrounds, controller configuration, or safe-area insets.
struct ExplorerWindowProbe: UIViewRepresentable {
    let onChange: (ExplorerWindowMetrics) -> Void

    func makeUIView(context _: Context) -> MeasurementView {
        let view = MeasurementView()
        view.isUserInteractionEnabled = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: MeasurementView, context _: Context) {
        view.onChange = onChange
        view.scheduleMeasurement()
    }

    final class MeasurementView: UIView {
        var onChange: ((ExplorerWindowMetrics) -> Void)?
        private var measurementScheduled = false
        private var lastMetrics: ExplorerWindowMetrics?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleMeasurement()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            scheduleMeasurement()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleMeasurement()
        }

        func scheduleMeasurement() {
            guard !measurementScheduled else { return }
            measurementScheduled = true
            // Publish after the current layout/update pass, not from within
            // SwiftUI's UIViewRepresentable update. No timer or polling is used.
            Task { @MainActor [weak self] in
                guard let self else { return }
                measurementScheduled = false
                measureWindow()
            }
        }

        private func measureWindow() {
            guard let window, !window.isHidden, !window.bounds.isEmpty,
                  let controller = window.rootViewController,
                  let rootView = controller.viewIfLoaded else { return }

            let metrics = ExplorerWindowMetrics(
                windowBounds: window.bounds,
                windowInsets: window.safeAreaInsets,
                rootFrame: rootView.convert(rootView.bounds, to: window),
                rootInsets: rootView.safeAreaInsets,
                additionalInsets: controller.additionalSafeAreaInsets
            )
            guard metrics != lastMetrics else { return }
            lastMetrics = metrics
            onChange?(metrics)
        }
    }
}
