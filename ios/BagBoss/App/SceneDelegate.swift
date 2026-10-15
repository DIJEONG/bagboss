import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var game: GameViewController? { window?.rootViewController as? GameViewController }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    // 제어 센터 · 전화 · 앱 전환기: 화면이 가려지는 순간 바로 멈춘다(웹이 아직 살아 있을 때)
    func sceneWillResignActive(_ scene: UIScene) { game?.appWillResignActive() }
    func sceneDidBecomeActive(_ scene: UIScene) { game?.appDidBecomeActive() }
    // 완전히 내려가면 저장을 디스크까지 밀어 넣는다(백그라운드 작업 시간 안에서)
    func sceneDidEnterBackground(_ scene: UIScene) { game?.appDidEnterBackground() }
}
