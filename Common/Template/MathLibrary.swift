/**
 * Copyright (c) 2019 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * t
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld. t
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

// Math Library v2.01
// added Rect

import simd

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

let π = Float.pi

extension Float {
  var radiansToDegrees: Float {
    (self / π) * 180
  }
  var degreesToRadians: Float {
    (self / 180) * π
  }
}

struct Rectangle {
  var left: Float = 0
  var right: Float = 0
  var top: Float = 0
  var bottom: Float = 0
}


func radians(fromDegrees degrees: Float) -> Float {
    return (degrees / 180) * π
}
// MARK:- float4x4
extension float4x4 {

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

    var upperLeftNormals: float3x3 {
        let x = columns.0.xyz
        let y = columns.1.xyz
        let z = columns.2.xyz
        return float3x3(columns: (x, y, z))
    }
  // MARK:- Translate
  init(translation: float3) {
    let matrix = float4x4(
      [            1,             0,             0, 0],
      [            0,             1,             0, 0],
      [            0,             0,             1, 0],
      [translation.x, translation.y, translation.z, 1]
    )
    self = matrix
  }
  
  // MARK:- Scale
  init(scaling: float3) {
    let matrix = float4x4(
      [scaling.x,         0,         0, 0],
      [        0, scaling.y,         0, 0],
      [        0,         0, scaling.z, 0],
      [        0,         0,         0, 1]
    )
    self = matrix
  }
  
  init(scaling: Float) {
    self = matrix_identity_float4x4
    columns.3.w = 1 / scaling
  }
  
  // MARK:- Rotate
  init(rotationX angle: Float) {
    let matrix = float4x4(
      [1,           0,          0, 0],
      [0,  cos(angle), sin(angle), 0],
      [0, -sin(angle), cos(angle), 0],
      [0,           0,          0, 1]
    )
    self = matrix
  }
  
  init(rotationY angle: Float) {
    let matrix = float4x4(
      [cos(angle), 0, -sin(angle), 0],
      [         0, 1,           0, 0],
      [sin(angle), 0,  cos(angle), 0],
      [         0, 0,           0, 1]
    )
    self = matrix
  }
  
  init(rotationZ angle: Float) {
    let matrix = float4x4(
      [ cos(angle), sin(angle), 0, 0],
      [-sin(angle), cos(angle), 0, 0],
      [          0,          0, 1, 0],
      [          0,          0, 0, 1]
    )
    self = matrix
  }
  
  init(rotation angle: float3) {
    let rotationX = float4x4(rotationX: angle.x)
    let rotationY = float4x4(rotationY: angle.y)
    let rotationZ = float4x4(rotationZ: angle.z)
    self = rotationX * rotationY * rotationZ
  }
  
  init(rotationYXZ angle: float3) {
    let rotationX = float4x4(rotationX: angle.x)
    let rotationY = float4x4(rotationY: angle.y)
    let rotationZ = float4x4(rotationZ: angle.z)
    self = rotationY * rotationX * rotationZ
  }
  
  // MARK:- Identity
  static func identity() -> float4x4 {
    matrix_identity_float4x4
  }
  
  // MARK:- Upper left 3x3
  var upperLeft: float3x3 {
    let x = columns.0.xyz
    let y = columns.1.xyz
    let z = columns.2.xyz
    return float3x3(columns: (x, y, z))
  }
  
  // MARK: - Left handed projection matrix
  init(projectionFov fov: Float, near: Float, far: Float, aspect: Float, lhs: Bool = true) {
    let y = 1 / tan(fov * 0.5)
    let x = y / aspect
    let z = lhs ? far / (far - near) : far / (near - far)
    let X = float4( x,  0,  0,  0)
    let Y = float4( 0,  y,  0,  0)
    let Z = lhs ? float4( 0,  0,  z, 1) : float4( 0,  0,  z, -1)
    let W = lhs ? float4( 0,  0,  z * -near,  0) : float4( 0,  0,  z * near,  0)
    self.init()
    columns = (X, Y, Z, W)
  }
  
  // left-handed LookAt
  init(eye: float3, center: float3, up: float3) {
    let z = normalize(center-eye)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    
    let X = float4(x.x, y.x, z.x, 0)
    let Y = float4(x.y, y.y, z.y, 0)
    let Z = float4(x.z, y.z, z.z, 0)
    let W = float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
    
    self.init()
    columns = (X, Y, Z, W)
  }
  
  // MARK:- Orthographic matrix
  init(orthoLeft left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) {
    let X = float4(2 / (right - left), 0, 0, 0)
    let Y = float4(0, 2 / (top - bottom), 0, 0)
    let Z = float4(0, 0, 1 / (far - near), 0)
    let W = float4((left + right) / (left - right),
                   (top + bottom) / (bottom - top),
                   near / (near - far),
                   1)
    self.init()
    columns = (X, Y, Z, W)
  }
  
  init(orthographic rect: Rectangle, near: Float, far: Float) {
    let X = float4(2 / (rect.right - rect.left), 0, 0, 0)
    let Y = float4(0, 2 / (rect.top - rect.bottom), 0, 0)
    let Z = float4(0, 0, 1 / (far - near), 0)
    let W = float4((rect.left + rect.right) / (rect.left - rect.right),
                   (rect.top + rect.bottom) / (rect.bottom - rect.top),
                   near / (near - far),
                   1)
    self.init()
    columns = (X, Y, Z, W)
  }
  
  
  // convert double4x4 to float4x4
  init(_ m: matrix_double4x4) {
    self.init()
    let matrix: float4x4 = float4x4(float4(m.columns.0),
                                    float4(m.columns.1),
                                    float4(m.columns.2),
                                    float4(m.columns.3))
    self = matrix
  }
}

// MARK:- float3x3
extension float3x3 {
  init(normalFrom4x4 matrix: float4x4) {
    self.init()
    columns = matrix.upperLeft.inverse.transpose.columns
  }
}

// MARK:- float4
extension float4 {
  var xyz: float3 {
    get {
      float3(x, y, z)
    }
    set {
      x = newValue.x
      y = newValue.y
      z = newValue.z
    }
  }
  
  // convert from double4
  init(_ d: SIMD4<Double>) {
    self.init()
    self = [Float(d.x), Float(d.y), Float(d.z), Float(d.w)]
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
        let cameraRotationMatrix: matrix_float3x3 = viewMatrix.upperLeft.inverse

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
