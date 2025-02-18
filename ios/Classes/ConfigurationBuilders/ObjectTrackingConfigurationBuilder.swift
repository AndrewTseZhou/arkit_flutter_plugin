import ARKit
import Foundation

@available(iOS 12.0, *)
func createObjectTrackingConfiguration(_: [String: Any]) -> ARObjectScanningConfiguration? {
    if ARObjectScanningConfiguration.isSupported {
        return ARObjectScanningConfiguration()
    }
    return nil
}
