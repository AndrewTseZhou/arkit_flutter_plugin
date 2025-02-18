import ARKit
import Foundation
import RealityKit
import SwiftUI
import os

class FlutterArkitView: NSObject, FlutterPlatformView {
    let sceneView: ARSCNView
    let channel: FlutterMethodChannel

    var forceTapOnCenter: Bool = false
    var configuration: ARConfiguration? = nil
    
    // 用于记录上一次的相机位置
    var lastCameraPosition: simd_float3? = nil
    var lastTimestamp: TimeInterval? = nil
    
    // 设定一个最小移动阈值 (单位：米)
    let minPositionDelta: Float = 0.05
    
    // 速度阈值（米/秒）
    let maxVelocity: Float = 1.0
    
    // 记录上一次提示“移动过快”的时间，避免频繁弹窗
    var lastVelocityWarningTime: TimeInterval?
    // 限制至少间隔多少秒后再提醒一次
    let velocityWarningCoolDown: TimeInterval = 5.0
    
    // 已创建的四棱锥的位置（用于避免重复创建）
    var createdPyramidsPositions: [simd_float3] = []
    
    var isRecording = false
    
    lazy var visionModel: VNCoreMLModel = {
        do {
            let model = try VNCoreMLModel(for: YOLOv3Tiny().model)
            return model
        } catch {
            fatalError("无法加载 ML 模型: \(error)")
        }
    }()

    init(withFrame frame: CGRect, viewIdentifier viewId: Int64, messenger msg: FlutterBinaryMessenger) {
        sceneView = ARSCNView(frame: frame)
        channel = FlutterMethodChannel(name: "arkit_\(viewId)", binaryMessenger: msg)

        super.init()

        sceneView.delegate = self
        sceneView.session.delegate = self
        channel.setMethodCallHandler(onMethodCalled)
    }

    func view() -> UIView { return sceneView }

    func onMethodCalled(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let arguments = call.arguments as? [String: Any]

        if configuration == nil && call.method != "init" {
            logPluginError("plugin is not initialized properly", toChannel: channel)
            result(nil)
            return
        }

        switch call.method {
        case "init":
            initalize(arguments!, result)
            result(nil)
        case "addARKitNode":
            onAddNode(arguments!)
            result(nil)
        case "onUpdateNode":
            onUpdateNode(arguments!)
            result(nil)
        case "removeARKitNode":
            onRemoveNode(arguments!)
            result(nil)
        case "removeARKitAnchor":
            onRemoveAnchor(arguments!)
            result(nil)
        case "addCoachingOverlay":
            if #available(iOS 13.0, *) {
                addCoachingOverlay(arguments!)
            }
            result(nil)
        case "removeCoachingOverlay":
            if #available(iOS 13.0, *) {
                removeCoachingOverlay()
            }
            result(nil)
        case "getNodeBoundingBox":
            onGetNodeBoundingBox(arguments!, result)
        case "transformationChanged":
            onTransformChanged(arguments!)
            result(nil)
        case "isHiddenChanged":
            onIsHiddenChanged(arguments!)
            result(nil)
        case "updateSingleProperty":
            onUpdateSingleProperty(arguments!)
            result(nil)
        case "updateMaterials":
            onUpdateMaterials(arguments!)
            result(nil)
        case "performHitTest":
            onPerformHitTest(arguments!, result)
        case "updateFaceGeometry":
            onUpdateFaceGeometry(arguments!)
            result(nil)
        case "getLightEstimate":
            onGetLightEstimate(result)
            result(nil)
        case "projectPoint":
            onProjectPoint(arguments!, result)
        case "cameraProjectionMatrix":
            onCameraProjectionMatrix(result)
        case "pointOfViewTransform":
            onPointOfViewTransform(result)
        case "playAnimation":
            onPlayAnimation(arguments!)
            result(nil)
        case "stopAnimation":
            onStopAnimation(arguments!)
            result(nil)
        case "dispose":
            onDispose(result)
            result(nil)
        case "cameraEulerAngles":
            onCameraEulerAngles(result)
            result(nil)
        case "cameraIntrinsics":
            onCameraIntrinsics(result)
        case "cameraImageResolution":
            onCameraImageResolution(result)
        case "snapshot":
            onGetSnapshot(result)
        case "capturedImage":
            onCameraCapturedImage(result)
        case "snapshotWithDepthData":
            onGetSnapshotWithDepthData(result)
        case "cameraPosition":
            onGetCameraPosition(result)
        case "setIsRecording":
            setIsRecording(arguments!)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func sendToFlutter(_ method: String, arguments: Any?) {
        DispatchQueue.main.async {
            self.channel.invokeMethod(method, arguments: arguments)
        }
    }

    func onDispose(_ result: FlutterResult) {
        sceneView.session.pause()
        channel.setMethodCallHandler(nil)
        result(nil)
    }
}
