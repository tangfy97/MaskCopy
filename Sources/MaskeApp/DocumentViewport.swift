import SwiftUI
import UIKit

/// UIScrollView owns scale, momentum and double-tap zoom. The bitmap is installed once.
struct DocumentViewport: UIViewRepresentable {
    let image: CGImage
    @Binding var zoom: CGFloat
    var quad: Binding<Quad>? = nil
    var hidden = true

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> Viewport {
        let view = Viewport()
        view.onZoom = { [weak coordinator = context.coordinator] value in
            guard let coordinator, abs(coordinator.parent.zoom - value) > 0.005 else { return }
            coordinator.parent.zoom = value
        }
        view.onEdit = { [weak coordinator = context.coordinator] value in coordinator?.parent.quad?.wrappedValue = value }
        return view
    }
    func updateUIView(_ view: Viewport, context: Context) {
        context.coordinator.parent = self
        view.accessibilityIdentifier = quad == nil ? "copy-viewport" : "mask-editor-canvas"
        view.configure(image: image, quad: quad?.wrappedValue, hidden: hidden, zoom: zoom)
    }
    final class Coordinator {
        var parent: DocumentViewport
        init(_ parent: DocumentViewport) { self.parent = parent }
    }

    final class Viewport: UIScrollView, UIScrollViewDelegate {
        private let picture = UIImageView()
        private let maskLayer = CAShapeLayer()
        private var handles: [Corner] = []
        private var source: CGImage?
        private var quad: Quad?
        private var start: Quad?
        private var hiddenMask = true
        private var viewportSize = CGSize.zero
        private var configuring = false
        var onZoom: ((CGFloat) -> Void)?
        var onEdit: ((Quad) -> Void)?

        init() {
            super.init(frame: .zero)
            delegate = self
            minimumZoomScale = 1
            maximumZoomScale = 8
            showsHorizontalScrollIndicator = false
            showsVerticalScrollIndicator = false
            contentInsetAdjustmentBehavior = .never
            backgroundColor = .clear
            picture.isUserInteractionEnabled = true
            picture.layer.addSublayer(maskLayer)
            addSubview(picture)
            let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
            tap.numberOfTapsRequired = 2
            addGestureRecognizer(tap)
            for index in 0..<4 {
                let corner = Corner(index: index)
                corner.accessibilityIdentifier = "mask-corner-\(index)"
                corner.accessibilityLabel = ["Top left corner", "Top right corner", "Bottom right corner", "Bottom left corner"][index]
                corner.accessibilityCustomActions = [("Move left", -1.0, 0.0), ("Move right", 1.0, 0.0),
                                                       ("Move up", 0.0, -1.0), ("Move down", 0.0, 1.0)].map { name, x, y in
                    UIAccessibilityCustomAction(name: name) { [weak self] _ in
                        guard let self, let quad = self.quad else { return false }
                        return self.move(index, from: quad, x: x / 500, y: y / 500)
                    }
                }
                let drag = UIPanGestureRecognizer(target: self, action: #selector(dragCorner(_:)))
                corner.addGestureRecognizer(drag)
                panGestureRecognizer.require(toFail: drag)
                picture.addSubview(corner)
                handles.append(corner)
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func configure(image: CGImage, quad: Quad?, hidden: Bool, zoom: CGFloat) {
            configuring = true
            defer { configuring = false }
            if source !== image {
                source = image
                picture.image = UIImage(cgImage: image)
                viewportSize = .zero
                setNeedsLayout()
            }
            self.quad = quad
            hiddenMask = hidden
            if abs(zoomScale - zoom) > 0.005, !isZooming { setZoomScale(zoom, animated: false) }
            updateMask()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.width > 0, bounds.height > 0, let source else { return }
            if viewportSize != bounds.size {
                configuring = true
                let scale = zoomScale
                setZoomScale(1, animated: false)
                let fit = min(max(1, bounds.width - 48) / CGFloat(source.width),
                              max(1, bounds.height - 48) / CGFloat(source.height))
                let size = CGSize(width: CGFloat(source.width) * fit, height: CGFloat(source.height) * fit)
                picture.frame = CGRect(origin: .zero, size: size)
                contentSize = size
                viewportSize = bounds.size
                setZoomScale(scale, animated: false)
                configuring = false
            }
            centerContent()
            updateMask()
        }

        private func centerContent() {
            let x = max(24, (bounds.width - contentSize.width) / 2)
            let y = max(24, (bounds.height - contentSize.height) / 2)
            let insets = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
            if contentInset != insets { contentInset = insets }
        }

        private func updateMask() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            maskLayer.isHidden = quad == nil
            for handle in handles { handle.isHidden = quad == nil }
            guard let quad else { return }
            let points = quad.points.map { CGPoint(x: $0.x * picture.bounds.width, y: $0.y * picture.bounds.height) }
            let path = UIBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.close()
            maskLayer.frame = picture.bounds
            maskLayer.path = path.cgPath
            maskLayer.fillColor = hiddenMask ? UIColor(cgColor: Renderer.maskColor).withAlphaComponent(0.28).cgColor : UIColor.clear.cgColor
            maskLayer.strokeColor = UIColor(Color.fjord).resolvedColor(with: traitCollection).cgColor
            maskLayer.lineWidth = 1.5 / zoomScale
            maskLayer.lineDashPattern = hiddenMask ? nil : [4 / zoomScale, 3 / zoomScale] as [NSNumber]
            for (index, handle) in handles.enumerated() {
                handle.center = points[index]
                handle.transform = CGAffineTransform(scaleX: 1 / zoomScale, y: 1 / zoomScale)
                let p = quad.points[index]
                handle.accessibilityValue = "\(Int(p.x * 100))% across, \(Int(p.y * 100))% down"
            }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { picture }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent()
            updateMask()
            if !configuring { onZoom?(zoomScale) }
        }

        @objc private func doubleTap(_ gesture: UITapGestureRecognizer) {
            if zoomScale > 1.05 { setZoomScale(1, animated: !UIAccessibility.isReduceMotionEnabled) }
            else {
                let point = gesture.location(in: picture)
                let size = CGSize(width: bounds.width / 2.5, height: bounds.height / 2.5)
                zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                width: size.width, height: size.height), animated: !UIAccessibility.isReduceMotionEnabled)
            }
        }

        @objc private func dragCorner(_ gesture: UIPanGestureRecognizer) {
            guard let handle = gesture.view as? Corner, let quad else { return }
            if gesture.state == .began { start = quad }
            if gesture.state == .changed, let start, picture.bounds.width > 0, picture.bounds.height > 0 {
                let delta = gesture.translation(in: picture)
                _ = move(handle.index, from: start, x: delta.x / picture.bounds.width, y: delta.y / picture.bounds.height)
            }
            if gesture.state == .ended || gesture.state == .cancelled { start = nil }
        }

        @discardableResult private func move(_ index: Int, from quad: Quad, x: CGFloat, y: CGFloat) -> Bool {
            var points = quad.points
            points[index].x = min(1, max(0, points[index].x + x))
            points[index].y = min(1, max(0, points[index].y + y))
            let candidate = Quad(tl: points[0], tr: points[1], br: points[2], bl: points[3])
            guard candidate.isConvex else { return false }
            self.quad = candidate
            updateMask()
            onEdit?(candidate)
            return true
        }
    }

    private final class Corner: UIControl {
        let index: Int
        private let dot = CAShapeLayer()
        init(index: Int) {
            self.index = index
            super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            isAccessibilityElement = true
            accessibilityTraits = .button
            layer.addSublayer(dot)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layoutSubviews() {
            super.layoutSubviews()
            dot.path = UIBezierPath(ovalIn: CGRect(x: 14, y: 14, width: 16, height: 16)).cgPath
            dot.fillColor = UIColor(Color.card).resolvedColor(with: traitCollection).cgColor
            dot.strokeColor = UIColor(Color.fjord).resolvedColor(with: traitCollection).cgColor
            dot.lineWidth = 2
        }
    }
}
