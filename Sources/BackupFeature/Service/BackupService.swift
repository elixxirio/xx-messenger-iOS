import UIKit
import Models
import Combine
import XXClient
import Defaults
import CloudFiles
import CloudFilesSFTP
import NetworkMonitor
import KeychainAccess
import XXMessengerClient
import DependencyInjection

public final class BackupService {
  @Dependency var messenger: Messenger
  @Dependency var networkManager: NetworkMonitoring

  @KeyObject(.email, defaultValue: nil) var email: String?
  @KeyObject(.phone, defaultValue: nil) var phone: String?
  @KeyObject(.username, defaultValue: nil) var username: String?
  @KeyObject(.backupSettings, defaultValue: nil) var storedSettings: Data?

  public var settingsPublisher: AnyPublisher<CloudSettings, Never> {
    settings.handleEvents(receiveSubscription: { [weak self] _ in
      guard let self = self else { return }
      self.settings.value.connectedServices = CloudFilesManager.all.linkedServices()
      CloudFilesManager.all.lastBackups { [weak self] in
        guard let self else { return }
        self.settings.value.backups = $0
      }
    }).eraseToAnyPublisher()
  }

  private var connType: ConnectionType = .wifi
  private var cancellables = Set<AnyCancellable>()
  private lazy var settings = CurrentValueSubject<CloudSettings, Never>(.init(fromData: storedSettings))

  public init() {
    settings
      .dropFirst()
      .removeDuplicates()
      .sink { [unowned self] in storedSettings = $0.toData() }
      .store(in: &cancellables)

    networkManager.connType
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] in connType = $0 }
      .store(in: &cancellables)
  }

  func didSetWiFiOnly(enabled: Bool) {
    settings.value.wifiOnlyBackup = enabled
  }

  func didSetAutomaticBackup(enabled: Bool) {
    settings.value.automaticBackups = enabled
    shouldBackupIfSetAutomatic()
  }

  func toggle(service: CloudService, enabling: Bool) {
    settings.value.enabledService = enabling ? service : nil
  }

  func didForceBackup() {
    if let lastBackup = try? Data(contentsOf: getBackupURL()) {
      performUpload(of: lastBackup)
    }
  }

  public func didUpdateFacts() {
    storeFacts()
  }

  public func updateLocalBackup(_ data: Data) {
    do {
      try data.write(to: getBackupURL())
      shouldBackupIfSetAutomatic()
    } catch {
      fatalError("Couldn't write backup to fileurl")
    }
  }

  private func shouldBackupIfSetAutomatic() {
    guard let lastBackup = try? Data(contentsOf: getBackupURL()) else {
      print(">>> No stored backup so won't upload anything.")
      return
    }
    guard settings.value.automaticBackups else {
      print(">>> Backups are not set to automatic")
      return
    }
    guard settings.value.enabledService != nil else {
      print(">>> No service enabled to upload")
      return
    }
    if settings.value.wifiOnlyBackup {
      guard connType == .wifi else {
        print(">>> WiFi only backups, and connType != Wifi")
        return
      }
    } else {
      guard connType != .unknown else {
        print(">>> Connectivity is unknown")
        return
      }
    }
    performUpload(of: lastBackup)
  }

  // MARK: - Messenger

  func initializeBackup(passphrase: String) {
    do {
      try messenger.startBackup(
        password: passphrase,
        params: .init(
          username: username!,
          email: email,
          phone: phone
        )
      )
    } catch {
      print(">>> Exception when calling `messenger.startBackup`: \(error.localizedDescription)")
    }
  }

  func stopBackups() {
    if messenger.isBackupRunning() == true {
      do {
        try messenger.stopBackup()
      } catch {
        print(">>> Exception when calling `messenger.stopBackup`: \(error.localizedDescription)")
      }
    }
  }

  func storeFacts() {
    var facts: [String: String] = [:]
    facts["username"] = username!
    facts["email"] = email
    facts["phone"] = phone
    facts["timestamp"] = "\(Date.asTimestamp)"
    guard let backupManager = messenger.backup.get() else {
      print(">>> Tried to store facts in JSON but there's no backup manager instance")
      return
    }
    guard let data = try? JSONSerialization.data(withJSONObject: facts) else {
      print(">>> Tried to generate data with json dictionary but failed")
      return
    }
    guard let string = String(data: data, encoding: .utf8) else {
      print(">>> Tried to extract string from json dict object but failed")
      return
    }
    backupManager.addJSON(string)
  }

  // MARK: - CloudProviders

  func setupSFTP(host: String, username: String, password: String) {
    let sftpManager = CloudFilesManager.sftp(
      host: host,
      username: username,
      password: password,
      fileName: "backup.xxm"
    )

    CloudFilesManager.all[.sftp] = sftpManager

    do {
      try sftpManager.fetch {
        switch $0 {
        case .success(let metadata):
          self.settings.value.backups[.sftp] = metadata
        case .failure(let error):
          print(">>> Error fetching sftp: \(error.localizedDescription)")
        }
      }
    } catch {
      print(">>> Exception fetching sftp: \(error.localizedDescription)")
    }
  }

  func authorize(
    service: CloudService,
    presenting screen: UIViewController
  ) {
    service.authorize(presenting: screen) {
      switch $0 {
      case .success:
        self.settings.value.connectedServices = CloudFilesManager.all.linkedServices()
        CloudFilesManager.all.lastBackups { [weak self] in
          guard let self else { return }
          self.settings.value.backups = $0
        }
      case .failure(let error):
        print(">>> Tried to authorize \(service) but failed: \(error.localizedDescription)")
      }
    }
  }

  func performUpload(of data: Data) {
    guard let enabledService = settings.value.enabledService else {
      fatalError(">>> Trying to backup but nothing is enabled")
    }

    if enabledService == .sftp {
      let keychain = Keychain(service: "SFTP-XXM")
      guard let host = try? keychain.get("host"),
            let password = try? keychain.get("pwd"),
            let username = try? keychain.get("username") else {
        fatalError(">>> Tried to perform an sftp backup but its not configured")
      }

      CloudFilesManager.all[.sftp] = .sftp(
        host: host,
        username: username,
        password: password,
        fileName: "backup.xxm"
      )
    }

    enabledService.backup(data: data) {
      switch $0 {
      case .success(let metadata):
        self.settings.value.backups[enabledService] = .init(
          size: metadata.size,
          lastModified: metadata.lastModified
        )
      case .failure(let error):
        print(">>> Failed to perform a backup upload: \(error.localizedDescription)")
      }
    }
  }

  private func getBackupURL() -> URL {
    guard let folderURL = try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ) else { fatalError(">>> Couldn't generate the URL for backup") }

    return folderURL
      .appendingPathComponent("backup")
      .appendingPathExtension("xxm")
  }
}
