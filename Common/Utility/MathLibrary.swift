
import simd

let π = Float.pi

func radians(fromDegrees degrees: Float) -> Float {
    return (degrees / 180) * π
}

func degrees(fromRadians radians: Float) -> Float {
    return (radians / π) * 180
}

struct Rectangle {
    var left: Float = 0
    var right: Float = 0
    var top: Float = 0
    var bottom: Float = 0
}

extension Float {
    var radiansToDegrees: Float {
        return (self / π) * 180
    }
    var degreesToRadians: Float {
        return (self / 180) * π
    }
}

extension float4x4 {
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3.x = t.x
        columns.3.y = t.y
        columns.3.z = t.z
    }

    init(scaling: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.0.x = scaling.x
        columns.1.y = scaling.y
        columns.2.z = scaling.z
    }

    init(scaling: Float) {
        self = matrix_identity_float4x4
        columns.3.w = 1 / scaling
    }

    init(rotationX angle: Float) {
        self = matrix_identity_float4x4
        columns.1.y = cos(angle)
        columns.1.z = sin(angle)
        columns.2.y = -sin(angle)
        columns.2.z = cos(angle)
    }

    init(rotationY angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.z = -sin(angle)
        columns.2.x = sin(angle)
        columns.2.z = cos(angle)
    }

    init(rotationZ angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.y = sin(angle)
        columns.1.x = -sin(angle)
        columns.1.y = cos(angle)
    }

    init(rotation angle: SIMD3<Float>) {
        let rotationX = float4x4(rotationX: angle.x)
        let rotationY = float4x4(rotationY: angle.y)
        let rotationZ = float4x4(rotationZ: angle.z)
        self = rotationX * rotationY * rotationZ
    }

    static func identity() -> float4x4 {
        let matrix:float4x4 = matrix_identity_float4x4
        return matrix
    }

    func upperLeft() -> float3x3 {
        let x = columns.0.xyz
        let y = columns.1.xyz
        let z = columns.2.xyz
        return float3x3(columns: (x, y, z))
    }

    init(projectionFov fov: Float, aspectRatio: Float, nearZ: Float, farZ: Float) {

        
         // Apple
        let ys = 1 / tanf(fov * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (farZ - nearZ)

        self.init(SIMD4<Float>(xs, 0, 0, 0),
                  SIMD4<Float>(0, ys, 0, 0),
                  // - here means it is Right handed dawg
                  SIMD4<Float>(0, 0, zs, 1),
                  SIMD4<Float>(0, 0, -nearZ * zs, 0))

// Ray
//        let lhs = true
//        let y = 1 / tan(fov * 0.5)
//        let x = y / aspectRatio
//        let z = lhs ? farZ / (farZ - nearZ) : farZ / (nearZ - farZ)
//        let X = float4( x,  0,  0,  0)
//        let Y = float4( 0,  y,  0,  0)
//        let Z = lhs ? float4( 0,  0, z, 1) : float4( 0,  0,  z, -1)
//        let W = lhs ? float4( 0,  0,  -nearZ * z,  0) : float4( 0,  0,  z * nearZ,  0)
//
//        self.init()
//        columns = (X, Y, Z, W)


//        let ys = 1 / tan(fov * 0.5)
//        let xs = ys / aspectRatio
//        let zRange = farZ - nearZ
//
//        let zs = -(farZ + nearZ) / zRange
//        let wz = -2 * farZ * nearZ / zRange
//
//        self.init(float4(xs,  0,  0,  0),
//                  float4( 0, ys,  0,  0),
//                  float4( 0,  0, zs, 1),
//                  float4( 0,  0, wz,  0))

    }

//    // Right hand? idk
//    init(perspectiveProjectionFov fovRadians: Float, aspectRatio aspect: Float, nearZ: Float, farZ: Float) {
//        let yScale = 1 / tan(fovRadians * 0.5)
//        let xScale = yScale / aspect
//        let zRange = farZ - nearZ
//        let zScale = -(farZ + nearZ) / zRange
//        let wzScale = -2 * farZ * nearZ / zRange
//
//        let xx = xScale
//        let yy = yScale
//        let zz = zScale
//        let zw = Float(-1)
//        let wz = wzScale
//
//        self.init(float4(xx,  0,  0,  0),
//                  float4( 0, yy,  0,  0),
//                  float4( 0,  0, zz, zw),
//                  float4( 0,  0, wz,  0))
//    }


    /*
    init(eye: float3, center: float3, up: float3) {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        let w = float3(dot(x, -eye), dot(y, -eye), dot(z, -eye))

        let X = float4(x.x, y.x, z.x, 0)
        let Y = float4(x.y, y.y, z.y, 0)
        let Z = float4(x.z, y.z, z.z, 0)
        let W = float4(w.x, w.y, x.z, 1)
        self.init()
        columns = (X, Y, Z, W)
    }
 */

    init(lookAtLHEye eye: vector_float3, target: vector_float3, up: vector_float3) {

        // LH: Target - Camera
        // RH: Camera - Target

        let z: vector_float3  = simd_normalize(target - eye);
        let x: vector_float3  = simd_normalize(simd_cross(up, z));
        let y: vector_float3  = simd_cross(z, x);
        let t: vector_float3 = vector_float3(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye));


        self.init(array: [x.x, y.x, z.x, 0,
                          x.y, y.y, z.y, 0,
                          x.z, y.z, z.z, 0,
                          t.x, t.y, t.z, 1])
    }


    init(orthographic rect: Rectangle, near: Float, far: Float) {
        let X = SIMD4<Float>(2 / (rect.right - rect.left), 0, 0, 0)
        let Y = SIMD4<Float>(0, 2 / (rect.top - rect.bottom), 0, 0)
        let Z = SIMD4<Float>(0, 0, 1 / (far - near), 0)
        let W = SIMD4<Float>((rect.left + rect.right) / (rect.left - rect.right),
                       (rect.top + rect.bottom) / (rect.bottom - rect.top),
                       near / (near - far),
                       1)
        self.init()
        columns = (X, Y, Z, W)
    }
}

extension float4x4 {
  init(array: [Float]) {
    guard array.count == 16 else {
      fatalError("presented array has \(array.count) elements - a float4x4 needs 16 elements")
    }
    self = matrix_identity_float4x4
    columns = (
      SIMD4<Float>( array[0],  array[1],  array[2],  array[3]),
      SIMD4<Float>( array[4],  array[5],  array[6],  array[7]),
      SIMD4<Float>( array[8],  array[9],  array[10], array[11]),
      SIMD4<Float>( array[12],  array[13],  array[14],  array[15])
    )
  }
}

extension SIMD3 where Scalar == Float {
  init(array: [Float]) {
    guard array.count == 3 else {
      fatalError("float3 array has \(array.count) elements - a float3 needs 3 elements")
    }
    self = SIMD3<Float>(array[0], array[1], array[2])
  }
}

extension SIMD4 where Scalar == Float {
  init(array: [Float]) {
    guard array.count == 4 else {
      fatalError("float4 array has \(array.count) elements - a float4 needs 4 elements")
    }
    self = SIMD4<Float>(array[0], array[1], array[2], array[3])
  }

  init(array: [Double]) {
    guard array.count == 4 else {
      fatalError("float4 array has \(array.count) elements - a float4 needs 4 elements")
    }
    self = SIMD4<Float>(Float(array[0]), Float(array[1]), Float(array[2]), Float(array[3]))
  }

}

extension simd_quatf {
  init(array: [Float]) {
    guard array.count == 4 else {
      fatalError("quaternion array has \(array.count) elements - a quaternion needs 4 Floats")
    }
    self = simd_quatf(ix: array[0], iy: array[1], iz: array[2], r: array[3])
  }
}

extension float3x3 {
    init(normalFrom4x4 matrix: float4x4) {
        self.init()
        columns = matrix.upperLeft().inverse.transpose.columns
    }
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        get {
            return SIMD3<Float>(x, y, z)
        }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }

    init(_ start: SIMD3<Float>, _ end: Float) {
        self.init(start.x, start.y, start.z, end)
    }
}

// Ported from https://developer.apple.com/documentation/metal/reflections_with_layer_selection
struct FrustumCuller {

    var position: vector_float3

    // planes normals :
    var norm_NearPlane: vector_float3
    var norm_LeftPlane: vector_float3
    var norm_RightPlane: vector_float3
    var norm_BottomPlane: vector_float3
    var norm_TopPlane: vector_float3

    // near / far distances from the frustum's origin
    var dist_Near: Float
    var dist_Far: Float

    init(viewMatrix: matrix_float4x4,
                  viewPosition: vector_float3,
                  aspect: Float,
                  halfAngleApertureHeight: Float,
                  nearPlaneDistance: Float,
                  farPlaneDistance: Float)
    {

        position = viewPosition
        dist_Far = farPlaneDistance
        dist_Near = nearPlaneDistance

        let halfAngleApertureWidth: Float = halfAngleApertureHeight * aspect
        // TODO: This might be broken
        let cameraRotationMatrix: matrix_float3x3 = viewMatrix.upperLeft().inverse

        norm_NearPlane = matrix_multiply(cameraRotationMatrix, SIMD3<Float>(0, 0, 1))
        norm_LeftPlane = matrix_multiply(cameraRotationMatrix,
                                         SIMD3<Float>(cosf(halfAngleApertureWidth), 0, sinf(halfAngleApertureWidth)))
        norm_BottomPlane = matrix_multiply(cameraRotationMatrix,
                                         SIMD3<Float>(0, cosf(halfAngleApertureHeight), sinf(halfAngleApertureHeight)))

        // TODO: This might be wrong too (-norm_LeftPLane etc etc)
        // we reflect the left plane normal along the view direction (norm_NearPlane) to get the right plane normal :
        norm_RightPlane = -norm_LeftPlane + norm_NearPlane * (simd_dot(norm_NearPlane, norm_LeftPlane) * 2);
        // we do the same, to get the top plane normal, from the bottom plane :
        norm_TopPlane = -norm_BottomPlane + norm_NearPlane * (simd_dot(norm_NearPlane, norm_BottomPlane) * 2);
    }

    func Intersects (actorPosition: vector_float3, bSphere: vector_float4) -> Bool {

        var bSphere = bSphere
        let position_f4: vector_float4  = vector_float4(actorPosition.x, actorPosition.y, actorPosition.z, 0.0)
        bSphere += position_f4;

        let bSphereRadius: Float = bSphere.w;
        let camToSphere: vector_float3 = bSphere.xyz - position;

        if (simd_dot (camToSphere + norm_NearPlane * (bSphereRadius-dist_Near), norm_NearPlane) < 0) { return false }
        if (simd_dot (camToSphere - norm_NearPlane * (bSphereRadius+dist_Far),  -norm_NearPlane) < 0) { return false }

        if (simd_dot (camToSphere + norm_LeftPlane * bSphereRadius, norm_LeftPlane) < 0) { return false }
        if (simd_dot (camToSphere + norm_RightPlane * bSphereRadius, norm_RightPlane) < 0) { return false }

        if (simd_dot (camToSphere + norm_BottomPlane * bSphereRadius, norm_BottomPlane) < 0) { return false }
        if (simd_dot (camToSphere + norm_TopPlane * bSphereRadius, norm_TopPlane) < 0) { return false }

        return true
    }
}
