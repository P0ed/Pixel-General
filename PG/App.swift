import UIKit
import SpriteKit
import COR

@MainActor var core: Core = .load()
@MainActor var settings: Settings = UserDefaults.standard.settings {
	didSet { UserDefaults.standard.settings = settings }
}
@MainActor let view = View()
@MainActor let controller = ViewController()
@MainActor var net: NetSession?

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {

		let cfg = UISceneConfiguration(
			name: "Main",
			sessionRole: connectingSceneSession.role
		)
		cfg.sceneClass = UIWindowScene.self
		cfg.delegateClass = SceneDelegate.self

		return cfg
	}
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow?

	func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		guard let scene = scene as? UIWindowScene else { return }

		let win = UIWindow(windowScene: scene)
		win.rootViewController = controller
		win.makeKeyAndVisible()
		window = win

		view.present(.auto)
	}
}
