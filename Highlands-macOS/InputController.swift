
import Cocoa

protocol KeyboardDelegate: class {
    func keyPressed(key: KeyboardControl, keysDown: Set<KeyboardControl>, state: InputState) -> Bool
}

protocol MouseDelegate: class {
    func mouseEvent(mouse: MouseControl, state: InputState, delta: SIMD3<Float>, location: SIMD2<Float>)
}

class InputController {

    var player: Node?
    weak var keyboardDelegate: KeyboardDelegate?
    var directionKeysDown: Set<KeyboardControl> = []

    var mouseDelegate: MouseDelegate?
    var useMouse = false

    var translationSpeed: Float = 10.0
    var rotationSpeed: Float = 2.0


    public func updatePlayer(deltaTime: Float) {
        guard let player = player else { return }

        let translationSpeed = deltaTime * self.translationSpeed
        let rotationSpeed = deltaTime * self.rotationSpeed
        var direction = SIMD3<Float>(repeating: 0)
        for key in directionKeysDown {
            switch key {
            case .w:
                direction.z += 1
            case .a:
                direction.x -= 1
            case.s:
                direction.z -= 1
            case .d:
                direction.x += 1
            case .left, .q:
                if let character = player as? Character, character.needsXRotationFix {
                    player.rotation.z += rotationSpeed
                } else {
                    player.rotation.y -= rotationSpeed
                }

            case .right, .e:
                if let character = player as? Character, character.needsXRotationFix {
                    player.rotation.z -= rotationSpeed
                } else {
                    player.rotation.y += rotationSpeed
                }
            default:
                break
            }
        }

        if direction != [0, 0, 0] {
            direction = normalize(direction)
//            let multiplier = (direction.z * player.forwardVector + direction.x * player.rightVector) * translationSpeed
//            player.position.x += multiplier.x
//            player.position.z += multiplier.z
            player.position += (direction.z * player.forwardVector + direction.x * player.rightVector) * translationSpeed
        }
    }

    func processEvent(key inKey: KeyboardControl, state: InputState) {

        if state == .began {
            directionKeysDown.insert(inKey)
        }
        if state == .ended {
            directionKeysDown.remove(inKey)
        }

        let _ = keyboardDelegate?.keyPressed(key: inKey, keysDown: directionKeysDown, state: state)
    }

    func processEvent(mouse: MouseControl, state: InputState, event: NSEvent) {
        let delta: SIMD3<Float> = [Float(event.deltaX), Float(event.deltaY), Float(event.deltaZ)]
        let locationInWindow: SIMD2<Float> = [Float(event.locationInWindow.x), Float(event.locationInWindow.y)]
        mouseDelegate?.mouseEvent(mouse: mouse, state: state, delta: delta, location: locationInWindow)
    }
}

enum InputState {
    case began, moved, ended, cancelled, continued
}

enum KeyboardControl: UInt16 {
    case a =      0
    case d =      2
    case w =      13
    case s =      1
    case down =   125
    case up =     126
    case right =  124
    case left =   123
    case q =      12
    case e =      14
    case key1 =   18
    case key2 =   19
    case key0 =   29
    case space =  49
    case c = 8
}

enum MouseControl {
    case leftDown, leftUp, leftDrag, rightDown, rightUp, rightDrag, scroll, mouseMoved
}

