//
//  Scene.swift
//  Highlands
//
//  Created by Scott Mehus on 12/21/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Foundation
import MetalKit

class Scene {

    var sceneSize: CGSize
    var cameras = [Camera()]
    var currentCameraIndex = 0
    var camera: Camera {
        return cameras[currentCameraIndex]
    }

    let rootNode = Node()
    var renderables = [Renderable]()
    var uniforms = Uniforms()
    var lights: [Light] = []
    let inputController = InputController()
    let physicsController = PhysicsController()
    var skybox: Skybox?

    lazy var lightPipelineState: MTLRenderPipelineState = {
        return buildLightPipelineState()
    }()


    init(sceneSize: CGSize) {
        self.sceneSize = sceneSize
        setupScene()
        mtkView(Renderer.mtkView, drawableSizeWillChange: sceneSize)
    }

    func setupScene() {
        // Must call super.setupScene at the end of subclass setupScene
        // To allow for models to be created first

        // I NEED TO CREATE EACH MODELS TEXTURES AFTER THIS
        // WHICH WILL POINT TO THE NEW TEXTURES CREATED IN BUILD HEAPPPP
        // WHICH MEANS I NEED TO FIND A WAY TO DO THISS....
        TextureController.heap = TextureController.buildHeap()
        for renderable in renderables {
            renderable.createTexturesBuffer()
        }
    }

    func isHardCollision() -> Bool {
        assertionFailure("Should override")
        return false
    }

    private func updatePlayer(deltaTime: Float) {
        guard let node = inputController.player else { return }
        let holdPosition = node.position
        let holdRotation = node.rotation
        inputController.updatePlayer(deltaTime: deltaTime)

        let playerMovement = node.position - holdPosition
        physicsController.checkPlayerCollisions(playerMovement: playerMovement)
        physicsController.checkPropCollisions(playerMovement: playerMovement)
    }

    final func update(deltaTime: Float) {
        updatePlayer(deltaTime: deltaTime)
        uniforms.projectionMatrix = camera.projectionMatrix
        uniforms.viewMatrix = camera.viewMatrix
        updateScene(deltaTime: deltaTime)
        update(nodes: rootNode.children, deltaTime: deltaTime)
    }

    private func update(nodes: [Node], deltaTime: Float) {
        nodes.forEach { node in
            node.update(deltaTime: deltaTime)
            update(nodes: node.children, deltaTime: deltaTime)
        }
    }

    func updateScene(deltaTime: Float) {
        // override this to update your scene
    }

    final func add(node: Node, parent: Node? = nil, render: Bool = true) {
        if let parent = parent {
            parent.add(childNode: node)
        } else {
            rootNode.add(childNode: node)
        }

        guard render == true, let renderable = node as? Renderable else { return }
        renderables.append(renderable)
    }

    final func remove(node: Node) {
        if let parent = node.parent {
            parent.remove(childNode: node)
        } else {
            for child in node.children {
                child.parent = nil
            }

            node.children = []
        }
        guard node is Renderable, let index = (renderables.firstIndex { $0 as? Node === node }) else { return }
        renderables.remove(at: index)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        for camera in cameras {
            camera.aspect = Float(size.width / size.height)
        }

        sceneSize = size
    }

    func render(view: MTKView, descriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) {
        assertionFailure("Must override \(#function)")
    }
}

extension Scene: TileSceneDelegate {
    func physicsControllAdd(_ node: Node) {
        physicsController.addStaticBody(node: node)
    }
}
