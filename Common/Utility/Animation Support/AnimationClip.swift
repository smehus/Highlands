
import MetalKit

class AnimationClip {
    let name: String
    var jointAnimation: [String: Animation?] = [:]
    var duration: Float = 0
    var speed: Float = 1

    init(name: String) {
        self.name = name
    }

    func getPose(at time: Float, jointPath: String) -> float4x4? {
        guard
            let jointAnimation = jointAnimation[jointPath] ?? nil
            else { return nil }
        let rotation =
            jointAnimation.getRotation(at: time) ?? simd_quatf()
        let translation =
            jointAnimation.getTranslation(at: time) ?? float3(repeating: 0)
        let pose = float4x4(translation: translation) * float4x4(rotation)
        return pose
    }
}
