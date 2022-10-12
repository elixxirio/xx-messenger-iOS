import Foundation

public struct BackupSettings: Equatable, Codable {
    public var wifiOnlyBackup: Bool
    public var automaticBackups: Bool
    public var enabledService: CloudService?
    public var connectedServices: Set<CloudService>
    public var backups: [CloudService: BackupModel]

    public init(
        wifiOnlyBackup: Bool = false,
        automaticBackups: Bool = false,
        enabledService: CloudService? = nil,
        connectedServices: Set<CloudService> = [],
        backups: [CloudService: BackupModel] = [:]
    ) {
        self.wifiOnlyBackup = wifiOnlyBackup
        self.automaticBackups = automaticBackups
        self.enabledService = enabledService
        self.connectedServices = connectedServices
        self.backups = backups
    }

    public func toData() -> Data {
        (try? PropertyListEncoder().encode(self)) ?? Data()
    }

    public init(fromData data: Data?) {
      if let data = data, let settings = try? PropertyListDecoder().decode(BackupSettings.self, from: data) {
        self.init(
          wifiOnlyBackup: settings.wifiOnlyBackup,
          automaticBackups: settings.automaticBackups,
          enabledService: settings.enabledService,
          connectedServices: settings.connectedServices,
          backups: settings.backups
        )
      } else {
        self.init(
          wifiOnlyBackup: false,
          automaticBackups: true,
          enabledService: nil,
          connectedServices: [],
          backups: [:]
        )
      }
    }
}

public struct RestoreSettings {
    public var backup: BackupModel?
    public var cloudService: CloudService

    public init(
        backup: BackupModel? = nil,
        cloudService: CloudService
    ) {
        self.backup = backup
        self.cloudService = cloudService
    }
}
