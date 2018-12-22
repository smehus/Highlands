
import MetalKit

extension Renderer {
}

func lighting() -> [Light] {
    var lights: [Light] = []

    var light = buildDefaultLight()
//    light.position = [-1, 0.5, -2]
//    light.intensity = 2.0
//    lights.append(light)
//
//    light = buildDefaultLight()
//    light.position = [0, 1, 2]
//    light.intensity = 0.2
//    lights.append(light)
//
//    light = buildDefaultLight()
//    light.type = Ambientlight
//    light.intensity = 0.1
//    lights.append(light)


    light.position = [0, 0, 0]
    light.color = [1, 0, 1]
    light.attenuation = float3(1, 0, 0)
    light.type = Spotlight
    light.coneAngle = radians(fromDegrees: 70)
    light.coneDirection = [-1.0, -1, 0]
    light.coneAttenuation = 5
    light.type = Spotlight
    lights.append(light)

    return lights
}

func buildDefaultLight() -> Light {
    var light = Light()
    light.position = [0, 0, 0]
    light.color = [1, 1, 1]
    light.specularColor = [0.6, 0.6, 0.6]
    light.intensity = 1
    light.attenuation = float3(1, 0, 0)
    light.type = Sunlight
    return light
}


