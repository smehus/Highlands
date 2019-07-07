
import MetalKit

extension Renderer {
}

func lighting() -> [Light] {
    var lights: [Light] = []


//    lights.append(spotlight())

    lights.append(lantern())

    var light = buildDefaultLight()
    light.position = [1, 2, -2]
    light.color = [0.2, 0.2, 0.2]
//    lights.append(light)

    light = buildDefaultLight()
    light.type = Ambientlight
    light.intensity = 0.1
//    lights.append(light)



    return lights
}

func lantern() -> Light {
    let pos: float3 = [0, 1, 0]
    var light = buildDefaultLight()
    light.color = [1, 1, 0.9]
    light.position = pos
    light.attenuation = float3(1, 0.01, 0.02)
    light.type = Pointlight
//    light.intensity = 10
    return light
}

func spotlight() -> Light {
    var light = buildDefaultLight()
    light.position = [0, 1, -1]
    light.color = [1, 1, 0.7]
    light.attenuation = float3(2, 0, 0)
    light.type = Spotlight
    light.coneAngle = radians(fromDegrees: 30)
    light.coneDirection = [0, -1, 1]
    light.coneAttenuation = 2
    light.type = Spotlight
    return light
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


