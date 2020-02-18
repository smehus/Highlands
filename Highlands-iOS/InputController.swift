
import MetalKit
import Foundation

protocol KeyboardDelegate: class {
    func didStartMove()
    func didEndMove()
}

class InputController {
    var player: Character?
    var currentSpeed: Float = 0


    var rotationSpeed: Float = 4.0
    var translationSpeed: Float = 0.15 {
        didSet {
            if translationSpeed > maxSpeed {
                translationSpeed = maxSpeed
            }
        }
    }
    let maxSpeed: Float = 0.15
    var currentTurnSpeed: Float = 0
    var currentPitch: Float = 0
    var forward = false

    weak var keyboardDelegate: KeyboardDelegate?
}

extension InputController {
    func processEvent(touches: Set<UITouch>, state: InputState, event: UIEvent?) {
        switch state {
        case .began:
            forward = true
            keyboardDelegate?.didStartMove()
        case .moved:
            forward = true
        case .ended:
            forward = false
            keyboardDelegate?.didEndMove()
        default:
            break
        }
    }

    public func updatePlayer(deltaTime: Float) {
        guard let player = player else { return }
        let translationSpeed = deltaTime * self.translationSpeed
        currentSpeed = forward ? currentSpeed + translationSpeed : currentSpeed - translationSpeed * 2

        if currentSpeed < 0 {
            currentSpeed = 0

        } else if currentSpeed > maxSpeed {
            currentSpeed = maxSpeed
        }

        if currentSpeed > 0 || self.translationSpeed > 0 {
            keyboardDelegate?.didStartMove()
        }

        if player.needsXRotationFix {
            player.rotation.z -= currentPitch * deltaTime * rotationSpeed
            player.position.x -= currentSpeed * sin(player.rotation.z)
            player.position.z += currentSpeed * cos(player.rotation.z)
        } else {
            player.rotation.y += currentPitch * deltaTime * rotationSpeed
            player.position.x += currentSpeed * sin(player.rotation.y)
            player.position.z += currentSpeed * cos(player.rotation.y)
        }
    }
}

enum InputState {
    case began, moved, ended, cancelled, continued
}
