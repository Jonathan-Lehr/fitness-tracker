#if os(iOS)
import UIKit

/// Per-screen orientation lock for iPhone. The app keeps its Info.plist orientations
/// (portrait + landscape on iPhone); a screen can temporarily restrict them, e.g. the
/// past-period summary sheet is portrait-only. The app delegate reports `mask` to UIKit,
/// which intersects it with Info.plist.
@MainActor
enum OrientationLock {
    /// No restriction beyond Info.plist.
    nonisolated static let unrestricted: UIInterfaceOrientationMask = .all

    private(set) static var mask: UIInterfaceOrientationMask = unrestricted

    /// The mask to apply for a screen that wants `portrait`, on the given device idiom.
    /// Only iPhone is restricted; iPad keeps every orientation (and multitasking).
    nonisolated static func mask(portraitOnly: Bool, idiom: UIUserInterfaceIdiom) -> UIInterfaceOrientationMask {
        portraitOnly && idiom == .phone ? .portrait : unrestricted
    }

    /// Lock to portrait (rotating if currently landscape) or release the lock, letting UIKit
    /// rotate back to the device's physical orientation.
    static func setPortraitOnly(_ portraitOnly: Bool) {
        let newMask = mask(portraitOnly: portraitOnly, idiom: UIDevice.current.userInterfaceIdiom)
        guard newMask != mask else { return }
        mask = newMask
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                var viewController = window.rootViewController
                while let controller = viewController {
                    controller.setNeedsUpdateOfSupportedInterfaceOrientations()
                    viewController = controller.presentedViewController
                }
            }
            if portraitOnly {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask)) { _ in }
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
#endif
