import ARKit
import SceneKit
import Foundation

extension FlutterArkitView: ARSCNViewDelegate, ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        // 可以在这里进行图像数据的处理，像保存图像或转化为图片格式
//        let pixelBuffer = capturedImage
//        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
//        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
//
//        // 将图像和位置信息发送给 Flutter
//        let imageData: [String: Any] = ["width": imageWidth, "height": imageHeight, "position": position]
//        sendToFlutter("onCameraImageUpdate", arguments: imageData)
        
        
        if (isRecording) {
            // 获取当前相机 transform
            let cameraTransform = frame.camera.transform
            // 从 transform.columns.3 里可以拿到 x,y,z
            let currentPosition = simd_float3(cameraTransform.columns.3.x,
                                              cameraTransform.columns.3.y,
                                              cameraTransform.columns.3.z)
            
            let currentTime = frame.timestamp
            // 说明是第一次更新，就记录一下
            guard let lastPos = lastCameraPosition,
                  let lastTime = lastTimestamp else {
                // 第一次数据，记录并返回
                lastCameraPosition = currentPosition
                lastTimestamp = currentTime
                return
            }
            
            // 计算与上一次位置的距离
            let dx = currentPosition.x - lastPos.x
            let dy = currentPosition.y - lastPos.y
            let dz = currentPosition.z - lastPos.z
            let distance = sqrt(dx * dx + dy * dy + dz * dz)
            
            // 当距离大于 minPositionDelta（阈值）时，认为有“明显移动”
            if distance > minPositionDelta {
                // 说明相机确实移动了
                if let bytes = UIImage(ciImage: CIImage(cvPixelBuffer: frame.capturedImage)).pngData() {
                    let res = FlutterStandardTypedData(bytes: bytes)
                    let imageData: [String: Any] = ["data": res]
                    sendToFlutter("onCameraImageUpdate", arguments: imageData)
                    if !hasCreatedPyramidAtPosition(currentPosition) {
                        addPyramidInFrontOfCamera(frame, distance: 0.1)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                }
                
                lastCameraPosition = currentPosition
            }
            
            let deltaTime = Float(currentTime - lastTime)
            guard deltaTime > 0 else {
                lastTimestamp = currentTime
                return
            }
            
            let velocity = distance / deltaTime
            
            // 如果超过阈值，弹出提醒
            if velocity > maxVelocity {
                let now = currentTime
                // 判断是否需要防止短时间内重复提醒
                if let lastWarning = lastVelocityWarningTime {
                    if (now - lastWarning) > velocityWarningCoolDown {
                        sendToFlutter("onMoveTooFast", arguments: nil)
                        lastVelocityWarningTime = now
                    }
                } else {
                    sendToFlutter("onMoveTooFast", arguments: nil)
                    lastVelocityWarningTime = now
                }
            }
            lastTimestamp = currentTime
            
            // 1. 获取当前帧的图像
            let pixelBuffer = frame.capturedImage
                
            // 2. 运行物体识别
            detectObjects(pixelBuffer: pixelBuffer)
        }
    }

    func session(_: ARSession, didFailWithError error: Error) {
        logPluginError("sessionDidFailWithError: \(error.localizedDescription)", toChannel: channel)
    }

    func session(_: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        var params = [String: NSNumber]()

        switch camera.trackingState {
        case .notAvailable:
            params["trackingState"] = 0
        case let .limited(reason):
            params["trackingState"] = 1
            switch reason {
            case .initializing:
                params["reason"] = 1
            case .relocalizing:
                params["reason"] = 2
            case .excessiveMotion:
                params["reason"] = 3
            case .insufficientFeatures:
                params["reason"] = 4
            default:
                params["reason"] = 0
            }
        case .normal:
            params["trackingState"] = 2
        }

        sendToFlutter("onCameraDidChangeTrackingState", arguments: params)
    }

    func sessionWasInterrupted(_: ARSession) {
        sendToFlutter("onSessionWasInterrupted", arguments: nil)
    }

    func sessionInterruptionEnded(_: ARSession) {
        sendToFlutter("onSessionInterruptionEnded", arguments: nil)
    }

    func renderer(_: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if node.name == nil {
            node.name = NSUUID().uuidString
        }
        let params = prepareParamsForAnchorEvent(node, anchor)
        sendToFlutter("didAddNodeForAnchor", arguments: params)
        
        if #available(iOS 13.4, *) {
//            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
//            let geometry = createMeshGeometry(from: meshAnchor)
//            let meshNode = SCNNode(geometry: geometry)
//            node.addChildNode(meshNode)

//            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
//            let meshNode = createMeshNode(from: meshAnchor)
//            node.addChildNode(meshNode)
        }
        
        if let objectAnchor = anchor as? ARObjectAnchor {
            // 获取物体的尺寸
            let extent = objectAnchor.referenceObject.extent
            print("Object recognized with extent: \(extent)")
            
            // 创建一个立方体框架
            let wireframeNode = createWireframe(extent: extent)
            
            // 将框架添加到锚点对应的节点上
            node.addChildNode(wireframeNode)
        }
    }

    func renderer(_: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        let params = prepareParamsForAnchorEvent(node, anchor)
        sendToFlutter("didUpdateNodeForAnchor", arguments: params)
        
        if #available(iOS 13.4, *) {
            // another way
//            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
//            node.enumerateChildNodes { (childNode, _) in
//                childNode.removeFromParentNode()
//            }
//            let meshNode = createMeshNode(from: meshAnchor)
//            node.addChildNode(meshNode)
        }
        
        if let objectAnchor = anchor as? ARObjectAnchor, let wireframeNode = node.childNodes.first {
            // 获取新的尺寸
            let extent = objectAnchor.referenceObject.extent
            
            // 更新框架的几何体
            let newWireframeNode = createWireframe(extent: extent)
            
            // 替换旧的框架
            wireframeNode.geometry = newWireframeNode.geometry
        }
    }

    func renderer(_: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        let params = prepareParamsForAnchorEvent(node, anchor)
        sendToFlutter("didRemoveNodeForAnchor", arguments: params)
    }

    func renderer(_: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let params = ["time": NSNumber(floatLiteral: time)]
        sendToFlutter("updateAtTime", arguments: params)
    }

    fileprivate func prepareParamsForAnchorEvent(_ node: SCNNode, _ anchor: ARAnchor) -> [String: Any] {
        var serializedAnchor = serializeAnchor(anchor)
        serializedAnchor["nodeName"] = node.name
        return serializedAnchor
    }

    @available(iOS 13.4, *)
    private func createMeshNode(from meshAnchor: ARMeshAnchor) -> SCNNode {
        // 提取网格几何数据
        let meshGeometry = meshAnchor.geometry
        
        // 创建顶点数据
        let vertices = meshGeometry.vertices
        let vertexSource = SCNGeometrySource(
            buffer: vertices.buffer,
            vertexFormat: vertices.format,
            semantic: .vertex,
            vertexCount: vertices.count,
            dataOffset: vertices.offset,
            dataStride: vertices.stride
        )
        
        // 创建面片索引数据
        let faces = meshGeometry.faces
        let faceData = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
        let element = SCNGeometryElement(
            data: faceData,
            primitiveType: .triangles,
            primitiveCount: faces.count,
            bytesPerIndex: faces.bytesPerIndex
        )
        
        // 创建几何体
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        
        // 设置材质（半透明绿色线框）
        let material = SCNMaterial()
        material.isDoubleSided = false // 关闭双面渲染
        material.fillMode = .lines // 线框模式
        material.diffuse.contents = UIColor.white
        geometry.materials = [material]
        
        return SCNNode(geometry: geometry)
    }
    
    // 添加四棱锥标识
    private func addPyramidInFrontOfCamera(_ frame: ARFrame, distance: Float = 0.1) {
        let cameraTransform = frame.camera.transform

        // 1. 获取相机在世界坐标系下的位置
        let cameraPosition = simd_float3(cameraTransform.columns.3.x,
                                         cameraTransform.columns.3.y,
                                         cameraTransform.columns.3.z)
        let qCamera = simd_quaternion(cameraTransform)
        let qFix = simd_quaternion(-Float.pi/2, simd_float3(1, 0, 0))
        let qFinal = simd_mul(qFix, qCamera)

        // 2. 获取“相机面向的方向”
        // 在 ARKit/SceneKit 中, camera 通常看向 -Z,
        // 所以 columns.2 往往代表相机向后的方向(负向前).
        // 因此要让模型出现在相机前面, 需要取 -columns.2.
        var forwardVector = -simd_float3(cameraTransform.columns.2.x,
                                         cameraTransform.columns.2.y,
                                         cameraTransform.columns.2.z)

        // 3. 归一化(单位化)方向向量，防止其长度不是 1 而导致距离计算不准确
        forwardVector = simd_normalize(forwardVector)

        // 4. 计算目标位置 = 相机位置 + 前方向量 * 距离
        let targetPosition = cameraPosition + forwardVector * distance

        // 5. 创建几何体(四棱锥), 单位 cm
        let pyramidWidth:  CGFloat = 0.05
        let pyramidHeight: CGFloat = 0.02
        let pyramid = SCNPyramid(width: pyramidWidth, height: pyramidHeight, length: pyramidWidth)

        // 6. 设置材质(颜色绿色等)
        let material = SCNMaterial()
        material.isDoubleSided = true // 关闭双面渲染
        material.fillMode = .lines // 线框模式
        material.diffuse.contents = UIColor.green
        pyramid.materials = [material]

        // 7. 创建 Node, 设置它的位置为我们计算好的 targetPosition
        let pyramidNode = SCNNode(geometry: pyramid)
        pyramidNode.position = SCNVector3(targetPosition.x,
                                          targetPosition.y,
                                          targetPosition.z)
        pyramidNode.simdOrientation = qFinal
        pyramidNode.simdPosition = targetPosition

        // 8. 可根据需要旋转一下让“锥尖”朝上或朝向你想要的方向
        pyramidNode.look(at: SCNVector3(cameraPosition.x, cameraPosition.y, cameraPosition.z))
        pyramidNode.eulerAngles.x += Float.pi / 2

        // 9. 将节点添加到当前场景中
        sceneView.scene.rootNode.addChildNode(pyramidNode)
    }

    // 判断相机当前位置是否已经创建过四棱锥
    private func hasCreatedPyramidAtPosition(_ position: simd_float3) -> Bool {
        for createdPos in createdPyramidsPositions {
            let dx = position.x - createdPos.x
            let dy = position.y - createdPos.y
            let dz = position.z - createdPos.z
            let distance = sqrt(dx*dx + dy*dy + dz*dz)
            if distance < minPositionDelta {
                return true  // 如果当前位置与已创建位置距离小于容忍度，认为已经创建过
            }
        }
        return false
    }
    
    func createWireframe(extent: SIMD3<Float>) -> SCNNode {
        let width = CGFloat(extent.x)
        let height = CGFloat(extent.y)
        let length = CGFloat(extent.z)
        
        // 定义立方体的 8 个顶点
        let vertices: [SCNVector3] = [
            SCNVector3(-width / 2, -height / 2, -length / 2), // Bottom-left-back
            SCNVector3(width / 2, -height / 2, -length / 2),  // Bottom-right-back
            SCNVector3(width / 2, -height / 2, length / 2),   // Bottom-right-front
            SCNVector3(-width / 2, -height / 2, length / 2),  // Bottom-left-front
            SCNVector3(-width / 2, height / 2, -length / 2),  // Top-left-back
            SCNVector3(width / 2, height / 2, -length / 2),   // Top-right-back
            SCNVector3(width / 2, height / 2, length / 2),    // Top-right-front
            SCNVector3(-width / 2, height / 2, length / 2)    // Top-left-front
        ]
        
        // 定义线的连接索引
        let indices: [UInt32] = [
            0, 1, 1, 2, 2, 3, 3, 0, // Bottom edges
            4, 5, 5, 6, 6, 7, 7, 4, // Top edges
            0, 4, 1, 5, 2, 6, 3, 7  // Vertical edges
        ]
        
        // 创建几何数据源
        let vertexSource = SCNGeometrySource(vertices: vertices)
        
        // 创建几何元素
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .line, // 线段模式
                                         primitiveCount: indices.count / 2,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)
        
        // 创建几何体
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        
        // 设置线框材质
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        material.isDoubleSided = true
        geometry.materials = [material]
        
        // 创建节点
        let wireframeNode = SCNNode(geometry: geometry)
        return wireframeNode
    }
    
    func createWireframe2(extent: SIMD3<Float>) -> SCNNode {
        let width = CGFloat(extent.x)
        let height = CGFloat(extent.y)
        let depth = CGFloat(extent.z)
        
        let box = SCNBox(width: width, height: height, length: depth, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        material.fillMode = .lines  // 线框模式
        box.materials = [material]
        
        let boxNode = SCNNode(geometry: box)
        return boxNode
    }
    
    func detectObjects(pixelBuffer: CVPixelBuffer) {
        print("detectObjects")
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            guard let results = request.results as? [VNClassificationObservation],
                    let firstResult = results.first else {
                return
            }
            
            // 获取最高置信度的物体
            let objectName = firstResult.identifier
            let confidence = firstResult.confidence
            
            DispatchQueue.main.async {
                self.displayDetectedObject(name: objectName, confidence: confidence)
            }
        }
        
        // 运行 Vision 物体检测
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print("Vision 物体检测失败: \(error)")
            }
        }
    }
    
    func displayDetectedObject(name: String, confidence: Float) {
        print("displayDetectedObject")
        // 1. 创建文本几何体
        let textGeometry = SCNText(string: "\(name) (\(Int(confidence * 100))%)", extrusionDepth: 0.1)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.red
        
        // 2. 创建文本节点
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.002, 0.002, 0.002)  // 缩小以适应 AR 画面
        
        // 3. 设置文本节点的位置（固定在摄像头前方）
        let cameraTransform = sceneView.session.currentFrame?.camera.transform
        let position = SCNVector3(
            x: cameraTransform?.columns.3.x ?? 0,
            y: cameraTransform?.columns.3.y ?? 0 - 0.1,  // 稍微往下偏移
            z: cameraTransform?.columns.3.z ?? 0 - 0.5   // 距离摄像头 0.5m
        )
        textNode.position = position
        
        // 4. 添加到场景
        sceneView.scene.rootNode.addChildNode(textNode)
    }
}
