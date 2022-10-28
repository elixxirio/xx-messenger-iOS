import UIKit
import BackgroundTasks

import Theme
import XXModels
import XXLogger
import Defaults
import PushFeature
import ToastFeature
import LaunchFeature
import CrashReporting
import DependencyInjection

import XXClient
import XXMessengerClient

import CloudFiles
import CloudFilesDrive
import CloudFilesICloud
import CloudFilesDropbox

public class AppDelegate: UIResponder, UIApplicationDelegate {
  @Dependency private var pushRouter: PushRouter
  @Dependency private var pushHandler: PushHandling
  @Dependency private var crashReporter: CrashReporter

  @KeyObject(.hideAppList, defaultValue: false) var hideAppList: Bool
  @KeyObject(.recordingLogs, defaultValue: true) var recordingLogs: Bool
  @KeyObject(.crashReporting, defaultValue: true) var isCrashReportingEnabled: Bool

  var calledStopNetwork = false
  var forceFailedPendingMessages = false

  var coverView: UIView?
  var backgroundTimer: Timer?
  public var window: UIWindow?

  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
#if DEBUG
    DependencyRegistrator.registerForMock()
#else
    DependencyRegistrator.registerForLive()
#endif

    if recordingLogs {
      XXLogger.start()
    }

    crashReporter.configure()
    crashReporter.setEnabled(isCrashReportingEnabled)

    UNUserNotificationCenter.current().delegate = self

    let window = Window()
    let navController = UINavigationController(rootViewController: LaunchController())
    window.rootViewController = StatusBarViewController(ToastViewController(navController))
    window.backgroundColor = UIColor.white
    window.makeKeyAndVisible()
    self.window = window

    DependencyInjection.Container.shared.register(
      PushRouter.live(navigationController: navController)
    )

    return true
  }

  public func application(application: UIApplication, shouldAllowExtensionPointIdentifier: String) -> Bool {
    false
  }

  public func applicationDidEnterBackground(_ application: UIApplication) {
    if let messenger = try? DependencyInjection.Container.shared.resolve() as Messenger,
       let database = try? DependencyInjection.Container.shared.resolve() as Database,
       let cMix = try? messenger.cMix.tryGet() {
      let backgroundTask = application.beginBackgroundTask(withName: "xx.stop.network") {}

      backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
        print(">>> .backgroundTimeRemaining: \(UIApplication.shared.backgroundTimeRemaining)")

        guard UIApplication.shared.backgroundTimeRemaining > 8 else {
          if !self.calledStopNetwork {
            self.calledStopNetwork = true
            try! messenger.stop()
            print(">>> Called stopNetworkFollower")
          } else {
            if cMix.hasRunningProcesses() == false {
              application.endBackgroundTask(backgroundTask)
              timer.invalidate()
            }
          }

          return
        }

        guard UIApplication.shared.backgroundTimeRemaining > 9 else {
          if !self.forceFailedPendingMessages {
            self.forceFailedPendingMessages = true

            let query = Message.Query(status: [.sending])
            let assignment = Message.Assignments(status: .sendingFailed)
            _ = try? database.bulkUpdateMessages(query, assignment)
          }

          return
        }
      })
    }
  }

  public func applicationWillResignActive(_ application: UIApplication) {
    if hideAppList {
      coverView?.removeFromSuperview()
      coverView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
      coverView?.frame = window?.bounds ?? .zero
      window?.addSubview(coverView!)
    }
  }

  public func applicationWillTerminate(_ application: UIApplication) {
    if let messenger = try? DependencyInjection.Container.shared.resolve() as Messenger {
      try? messenger.stop()
    }
  }

  public func applicationWillEnterForeground(_ application: UIApplication) {
    if backgroundTimer != nil {
      backgroundTimer?.invalidate()
      backgroundTimer = nil
      print(">>> Invalidated background timer")
    }

    if let messenger = try? DependencyInjection.Container.shared.resolve() as Messenger,
       let cMix = messenger.cMix.get() {
      guard self.calledStopNetwork == true else { return }
      try? cMix.startNetworkFollower(timeoutMS: 10_000)
      print(">>> Called startNetworkFollower")
      self.calledStopNetwork = false
    }
  }

  public func applicationDidBecomeActive(_ application: UIApplication) {
    application.applicationIconBadgeNumber = 0
    coverView?.removeFromSuperview()
  }

  public func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    handleRedirectURL(url)
  }

  public func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let incomingURL = userActivity.webpageURL,
          let username = getUsernameFromInvitationDeepLink(incomingURL),
          let router = try? DependencyInjection.Container.shared.resolve() as PushRouter else {
      return false
    }

    router.navigateTo(.search(username: username), {})
    return true
  }
}

func getUsernameFromInvitationDeepLink(_ url: URL) -> String? {
  if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
     components.scheme == "https",
     components.host == "elixxir.io",
     components.path == "/connect",
     let queryItem = components.queryItems?.first(where: { $0.name == "username" }),
     let username = queryItem.value {
    return username
  }

  return nil
}

// MARK: Notifications

extension AppDelegate: UNUserNotificationCenterDelegate {
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    pushHandler.handleAction(pushRouter, userInfo, completionHandler)
  }

  public func application(
    _ application: UIApplication,
    didReceiveRemoteNotification notification: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    pushHandler.handlePush(notification, completionHandler)
  }

  public func application(
    _: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    pushHandler.registerToken(deviceToken)
  }
}
