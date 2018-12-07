import Cocoa

extension ViewController {
    func addGestureRecognizer(to view: NSView) {
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(gesture:)))
        view.addGestureRecognizer(pan)
    }

    @objc func handlePan(gesture: NSPanGestureRecognizer) {
        let translation = float2(Float(gesture.translation(in: gesture.view).x),
                                 Float(gesture.translation(in: gesture.view).y))

        renderer?.rotateUsing(translation: translation)
        gesture.setTranslation(.zero, in: gesture.view)
    }

    override func scrollWheel(with event: NSEvent) {
        let sensitivity: Float = 0.1
        renderer?.zoomUsing(delta: event.deltaY,
                            sensitivity: sensitivity)
    }
}

