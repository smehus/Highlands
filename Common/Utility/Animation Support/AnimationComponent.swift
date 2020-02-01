
import MetalKit

struct AnimationComponent {
    let animations: [String: AnimationClip]

    init(asset: MDLAsset) {
        let animations: [MDLPackedJointAnimation] = asset.animations.objects.compactMap {
            $0 as? MDLPackedJointAnimation
        }
        self.animations = Dictionary(uniqueKeysWithValues: animations.map {
            ($0.name, AnimationComponent.load(animation: $0))})
    }

    static func load(animation: MDLPackedJointAnimation) -> AnimationClip {
        let name = URL(string: animation.name)?.lastPathComponent ?? "Untitled"
        let animationClip = AnimationClip(name: name)
        var duration: Float = 0
        for (jointIndex, jointPath) in animation.jointPaths.enumerated() {
            var jointAnimation = Animation()

            let rotationTimes = animation.rotations.times
            if let lastTime = rotationTimes.last,
                duration < Float(lastTime) {
                duration = Float(lastTime)
            }
            jointAnimation.rotations = rotationTimes.enumerated().map {
                (index, time) in
                let startIndex = index * animation.jointPaths.count
                let endIndex = startIndex + animation.jointPaths.count

                let array = Array(animation.rotations.floatQuaternionArray[startIndex..<endIndex])
                return KeyQuaternion(time: Float(time),
                                     value: array[jointIndex])
            }

            let translationTimes = animation.translations.times
            if let lastTime = translationTimes.last,
                duration < Float(lastTime) {
                duration = Float(lastTime)
            }
            jointAnimation.translations = translationTimes.enumerated().map {
                (index, time) in
                let startIndex = index * animation.jointPaths.count
                let endIndex = startIndex + animation.jointPaths.count

                let array = Array(animation.translations.float3Array[startIndex..<endIndex])
                return Keyframe(time: Float(time),
                                value: array[jointIndex])
            }
            animationClip.jointAnimation[jointPath] = jointAnimation
        }
        return animationClip
    }


}
