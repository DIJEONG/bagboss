import UIKit

/// UIKit 수명주기를 쓴다(SwiftUI 아님): 상태 막대 · 홈 인디케이터 · 하단 제스처 지연을
/// 루트 뷰 컨트롤러에서 직접 정해야 하는 전체 화면 게임이라서.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
