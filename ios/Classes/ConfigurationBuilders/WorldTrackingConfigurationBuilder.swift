import ARKit
import Foundation
import RealityKit
import SceneKit

func createWorldTrackingConfiguration(_ arguments: [String: Any]) -> ARWorldTrackingConfiguration? {
    if ARWorldTrackingConfiguration.isSupported {
        let worldTrackingConfiguration = ARWorldTrackingConfiguration()
        if let referenceObjects = ARReferenceObject.referenceObjects(inGroupNamed: "ARObjects", bundle: nil) {
            worldTrackingConfiguration.detectionObjects = referenceObjects
        } else {
            print("Failed to load reference objects.")
        }
        if #available(iOS 13.4, *) {
            worldTrackingConfiguration.sceneReconstruction = .meshWithClassification
        }
        if let environmentTexturing = arguments["environmentTexturing"] as? Int {
            if environmentTexturing == 0 {
                worldTrackingConfiguration.environmentTexturing = .none
            } else if environmentTexturing == 1 {
                worldTrackingConfiguration.environmentTexturing = .manual
            } else if environmentTexturing == 2 {
                worldTrackingConfiguration.environmentTexturing = .automatic
            }
        }
        if let planeDetection = arguments["planeDetection"] as? Int {
            if planeDetection == 1 {
                worldTrackingConfiguration.planeDetection = .horizontal
            }
            if planeDetection == 2 {
                worldTrackingConfiguration.planeDetection = .vertical
            }
            if planeDetection == 3 {
                worldTrackingConfiguration.planeDetection = [.horizontal, .vertical]
            }
        }
        if let detectionImagesGroupName = arguments["detectionImagesGroupName"] as? String {
            worldTrackingConfiguration.detectionImages = ARReferenceImage.referenceImages(inGroupNamed: detectionImagesGroupName, bundle: nil)
        }
        if let detectionImages = arguments["detectionImages"] as? [[String: Any]] {
            worldTrackingConfiguration.detectionImages = parseReferenceImagesSet(detectionImages)
        }
        if let maximumNumberOfTrackedImages = arguments["maximumNumberOfTrackedImages"] as? Int {
            worldTrackingConfiguration.maximumNumberOfTrackedImages = maximumNumberOfTrackedImages
        }

        return worldTrackingConfiguration
    }
    return nil
}
