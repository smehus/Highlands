//
//  Scene.swift
//  Highlands
//
//  Created by Scott Mehus on 12/21/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Foundation

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

    init(sceneSize: CGSize) {
        self.sceneSize = sceneSize
        setupScene()
        sceneSizeWillChange(to: sceneSize)
    }

    func setupScene() {
        assertionFailure("Must Subclass Scene")
    }

    final func update(deltaTime: Float) {

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
        guard render == true, let renderable = node as? Renderable else {
            return
        }
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
        guard node is Renderable, let index = (renderables.index { $0 as? Node === node }) else { return }
        renderables.remove(at: index)
    }

    func sceneSizeWillChange(to size: CGSize) {
        for camera in cameras {
            camera.aspect = Float(size.width / size.height)
        }
        sceneSize = size
    }
}