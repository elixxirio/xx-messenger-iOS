import Retry
import os.log
import Models
import Shared
import Combine
import Defaults
import XXModels
import XXDatabase
import Foundation
import ToastFeature
import BackupFeature
import NetworkMonitor
import ReportingFeature
import DependencyInjection
import XXLegacyDatabaseMigrator

let logHandler = OSLog(subsystem: "xx.network", category: "Performance debugging")

struct BackupParameters: Codable {
    var email: String?
    var phone: String?
    var username: String
}

struct BackupReport: Codable {
    var contactIds: [String]
    var parameters: String

    private enum CodingKeys: String, CodingKey {
        case parameters = "Params"
        case contactIds = "RestoredContacts"
    }
}

public final class Session: SessionType {
    @KeyObject(.theme, defaultValue: nil) var theme: String?
    @KeyObject(.email, defaultValue: nil) var email: String?
    @KeyObject(.phone, defaultValue: nil) var phone: String?
    @KeyObject(.avatar, defaultValue: nil) var avatar: Data?
    @KeyObject(.username, defaultValue: nil) var username: String?
    @KeyObject(.biometrics, defaultValue: false) var biometrics: Bool
    @KeyObject(.hideAppList, defaultValue: false) var hideAppList: Bool
    @KeyObject(.requestCounter, defaultValue: 0) var requestCounter: Int
    @KeyObject(.sharingEmail, defaultValue: false) var isSharingEmail: Bool
    @KeyObject(.sharingPhone, defaultValue: false) var isSharingPhone: Bool
    @KeyObject(.recordingLogs, defaultValue: true) var recordingLogs: Bool
    @KeyObject(.crashReporting, defaultValue: true) var crashReporting: Bool
    @KeyObject(.icognitoKeyboard, defaultValue: false) var icognitoKeyboard: Bool
    @KeyObject(.pushNotifications, defaultValue: false) var pushNotifications: Bool
    @KeyObject(.inappnotifications, defaultValue: true) var inappnotifications: Bool

    @Dependency var backupService: BackupService
    @Dependency var toastController: ToastController
    @Dependency var reportingStatus: ReportingStatus
    @Dependency var networkMonitor: NetworkMonitoring

    public let client: Client
    public let dbManager: Database
    private var cancellables = Set<AnyCancellable>()

    public var myId: Data { client.bindings.myId }
    public var version: String { type(of: client.bindings).version }

    public var myQR: Data {
        client
            .bindings
            .meMarshalled(
                username!,
                email: isSharingEmail ? email : nil,
                phone: isSharingPhone ? phone : nil
            )
    }

    public var hasRunningTasks: Bool {
        client.bindings.hasRunningTasks
    }

    public var isOnline: AnyPublisher<Bool, Never> {
        networkMonitor.statusPublisher.map { $0 == .available }.eraseToAnyPublisher()
    }

    public init(
        passphrase: String,
        backupFile: Data,
        ndf: String
    ) throws {
        let network = try! DependencyInjection.Container.shared.resolve() as XXNetworking

        os_signpost(.begin, log: logHandler, name: "Decrypting", "Calling newClientFromBackup")
        let (client, backupData) = try network.newClientFromBackup(passphrase: passphrase, data: backupFile, ndf: ndf)
        os_signpost(.end, log: logHandler, name: "Decrypting", "Finished newClientFromBackup")

        self.client = client

        let legacyOldPath = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        )[0].appending("/xxmessenger.sqlite")

        let legacyPath = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.elixxir.messenger")!
            .appendingPathComponent("database")
            .appendingPathExtension("sqlite").path

        let dbExistsInLegacyOldPath = FileManager.default.fileExists(atPath: legacyOldPath)
        let dbExistsInLegacyPath = FileManager.default.fileExists(atPath: legacyPath)

        if dbExistsInLegacyOldPath && !dbExistsInLegacyPath {
            try? FileManager.default.moveItem(atPath: legacyOldPath, toPath: legacyPath)
        }

        let dbPath = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.elixxir.messenger")!
            .appendingPathComponent("xxm_database")
            .appendingPathExtension("sqlite").path

        dbManager = try Database.onDisk(path: dbPath)

        if dbExistsInLegacyPath {
            try Migrator.live()(
                try .init(path: legacyPath),
                to: dbManager,
                myContactId: client.bindings.myId,
                meMarshaled: client.bindings.meMarshalled
            )

            try FileManager.default.moveItem(atPath: legacyPath, toPath: legacyPath.appending("-backup"))
        }

        let report = try! JSONDecoder().decode(BackupReport.self, from: backupData!)

        if !report.parameters.isEmpty {
            let params = try! JSONDecoder().decode(BackupParameters.self, from: Data(report.parameters.utf8))

            username = params.username

            if let paramsPhone = params.phone, !paramsPhone.isEmpty {
                phone = paramsPhone
            }

            if let paramsEmail = params.email, !paramsEmail.isEmpty {
                email = paramsEmail
            }
        }

        guard let username = username, username.isEmpty == false else {
            fatalError("Trying to restore an account that has no username")
        }

        try continueInitialization()

        if !report.contactIds.isEmpty {
            client.restoreContacts(fromBackup: try! JSONSerialization.data(withJSONObject: report.contactIds))
        }
    }

    public init(ndf: String) throws {
        let network = try! DependencyInjection.Container.shared.resolve() as XXNetworking
        self.client = try network.newClient(ndf: ndf)

        let legacyOldPath = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        )[0].appending("/xxmessenger.sqlite")

        let legacyPath = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.elixxir.messenger")!
            .appendingPathComponent("database")
            .appendingPathExtension("sqlite").path

        let dbExistsInLegacyOldPath = FileManager.default.fileExists(atPath: legacyOldPath)
        let dbExistsInLegacyPath = FileManager.default.fileExists(atPath: legacyPath)

        if dbExistsInLegacyOldPath && !dbExistsInLegacyPath {
            try? FileManager.default.moveItem(atPath: legacyOldPath, toPath: legacyPath)
        }

        let dbPath = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.elixxir.messenger")!
            .appendingPathComponent("xxm_database")
            .appendingPathExtension("sqlite").path

        dbManager = try Database.onDisk(path: dbPath)

        if dbExistsInLegacyPath {
            try Migrator.live()(
                try .init(path: legacyPath),
                to: dbManager,
                myContactId: client.bindings.myId,
                meMarshaled: client.bindings.meMarshalled
            )

            try FileManager.default.moveItem(atPath: legacyPath, toPath: legacyPath.appending("-backup"))
        }

        try continueInitialization()
    }

    private func continueInitialization() throws {
        var myContact = try self.myContact()
        myContact.marshaled = client.bindings.meMarshalled
        myContact.username = username
        myContact.email = email
        myContact.phone = phone
        myContact.authStatus = .friend
        myContact.isRecent = false
        _ = try dbManager.saveContact(myContact)

        setupBindings()
        networkMonitor.start()

        networkMonitor.statusPublisher
            .filter { $0 == .available }.first()
            .sink { [unowned self] _ in
                client.bindings.replayRequests()
                scanStrangers {}
            }
            .store(in: &cancellables)

        registerUnfinishedUploadTransfers()
        registerUnfinishedDownloadTransfers()

        let query = Contact.Query(authStatus: [.verificationInProgress])
        _ = try? dbManager.bulkUpdateContacts(query, .init(authStatus: .verificationFailed))
    }

    public func setDummyTraffic(status: Bool) {
        client.dummyManager?.setStatus(status: status)
    }

    public func deleteMyself() throws {
        guard let username = username, let ud = client.userDiscovery else { return }

        try? unregisterNotifications()
        try ud.deleteMyself(username)

        stop()
        cleanUp()
    }

    private func cleanUp() {
        retry(max: 10, retryStrategy: .delay(seconds: 1)) { [unowned self] in
            guard self.hasRunningTasks == false else { throw NSError.create("") }
        }.finalCatch { _ in fatalError("Couldn't delete account because network is not stopping") }

        try! dbManager.drop()
        FileManager.xxCleanup()

        email = nil
        phone = nil
        theme = nil
        avatar = nil
        self.username = nil
        isSharingEmail = false
        isSharingPhone = false
        requestCounter = 0
        biometrics = false
        hideAppList = false
        recordingLogs = true
        crashReporting = true
        icognitoKeyboard = false
        pushNotifications = false
        inappnotifications = true
    }

    private func registerUnfinishedDownloadTransfers() {
        guard let unfinishedReceivingMessages = try? dbManager.fetchMessages(.init(status: [.receiving])),
              let unfinishedReceivingTransfers = try? dbManager.fetchFileTransfers(.init(
                id: Set(unfinishedReceivingMessages
                    .filter { $0.fileTransferId != nil }
                    .compactMap(\.fileTransferId))))
        else { return }

        let pairs = unfinishedReceivingMessages.compactMap { message -> (Message, FileTransfer)? in
            guard let transfer = unfinishedReceivingTransfers.first(where: { ft in
                ft.id == message.fileTransferId
            }) else { return nil }

            return (message, transfer)
        }

        pairs.forEach { message, transfer in
            var message = message
            var transfer = transfer

            do {
                try client.transferManager?.listenDownloadFromTransfer(with: transfer.id) { [weak self] completed, received, total, error in
                    guard let self = self else { return }
                    if completed {
                        transfer.progress = 1.0
                        message.status = .received

                        if let data = try? self.client.transferManager?.downloadFileFromTransfer(with: transfer.id),
                           let _ = try? FileManager.store(data: data, name: transfer.name, type: transfer.type) {
                            transfer.data = data
                        }
                    } else {
                        if error != nil {
                            message.status = .receivingFailed
                        } else {
                            transfer.progress = Float(received)/Float(total)
                        }
                    }

                    _ = try? self.dbManager.saveFileTransfer(transfer)
                    _ = try? self.dbManager.saveMessage(message)
                }
            } catch {
                message.status = .receivingFailed
                _ = try? self.dbManager.saveMessage(message)
            }
        }
    }

    private func registerUnfinishedUploadTransfers() {
        guard let unfinishedSendingMessages = try? dbManager.fetchMessages(.init(status: [.sending])),
              let unfinishedSendingTransfers = try? dbManager.fetchFileTransfers(.init(
                id: Set(unfinishedSendingMessages
                    .filter { $0.fileTransferId != nil }
                    .compactMap(\.fileTransferId))))
        else { return }

        let pairs = unfinishedSendingMessages.compactMap { message -> (Message, FileTransfer)? in
            guard let transfer = unfinishedSendingTransfers.first(where: { ft in
                ft.id == message.fileTransferId
            }) else { return nil }

            return (message, transfer)
        }

        pairs.forEach { message, transfer in
            var message = message
            var transfer = transfer

            do {
                try client.transferManager?.listenUploadFromTransfer(with: transfer.id) { [weak self] completed, sent, arrived, total, error in
                    guard let self = self else { return }

                    if completed {
                        transfer.progress = 1.0
                        message.status = .sent

                        try? self.client.transferManager?.endTransferUpload(with: transfer.id)
                    } else {
                        if error != nil {
                            message.status = .sendingFailed
                        } else {
                            transfer.progress = Float(arrived)/Float(total)
                        }
                    }

                    _ = try? self.dbManager.saveFileTransfer(transfer)
                    _ = try? self.dbManager.saveMessage(message)
                }
            } catch {
                message.status = .sendingFailed
                _ = try? self.dbManager.saveMessage(message)
            }
        }
    }

    func updateFactsOnBackup() {
        struct BackupParameters: Codable {
            var email: String?
            var phone: String?
            var username: String

            var jsonFormat: String {
                let data = try! JSONEncoder().encode(self)
                let json = String(data: data, encoding: .utf8)
                return json!
            }
        }

        let params = BackupParameters(
            email: email,
            phone: phone,
            username: username!
        ).jsonFormat

        client.addJson(params)

        guard username!.isEmpty == false else {
            fatalError("Tried to build a backup with my username but an empty string was set to it")
        }

        backupService.performBackupIfAutomaticIsEnabled()
    }

    private func setupBindings() {
        client.requests
            .sink { [unowned self] contact in
                let query = Contact.Query(id: [contact.id])

                if let prexistent = try? dbManager.fetchContacts(query).first {
                    guard prexistent.authStatus == .stranger else { return }
                }

                if self.inappnotifications {
                    DeviceFeedback.sound(.contactAdded)
                    DeviceFeedback.shake(.notification)
                }

                verify(contact: contact)
            }.store(in: &cancellables)

        client.requestsSent
            .sink { [unowned self] in _ = try? dbManager.saveContact($0) }
            .store(in: &cancellables)

        client.backup
            .sink { [unowned self] in backupService.updateBackup(data: $0) }
            .store(in: &cancellables)

        client.resets
            .sink { [unowned self] in
                /// This will get called when my contact restore its contact.
                /// TODO: Hold a record on the chat that this contact restored.
                ///
                if var contact = try? dbManager.fetchContacts(.init(id: [$0.id])).first {
                    contact.authStatus = .friend
                    _ = try? dbManager.saveContact(contact)
                }
            }.store(in: &cancellables)

        backupService.settingsPublisher
            .map { $0.enabledService != nil }
            .removeDuplicates()
            .sink { [unowned self] in
                if $0 == true {
                    guard let passphrase = backupService.passphrase else {
                        client.resumeBackup()
                        return
                    }

                    client.initializeBackup(passphrase: passphrase)
                    backupService.passphrase = nil
                    updateFactsOnBackup()
                } else {
                    backupService.passphrase = nil
                    client.stopListeningBackup()
                }
            }
            .store(in: &cancellables)

        client.messages
            .sink { [unowned self] in
                if var contact = try? dbManager.fetchContacts(.init(id: [$0.senderId])).first {
                    guard contact.isBanned == false else { return }
                    contact.isRecent = false
                    _ = try? dbManager.saveContact(contact)
                }

                _ = try? dbManager.saveMessage($0)
            }.store(in: &cancellables)

        client.network
            .sink { [unowned self] in networkMonitor.update($0) }
            .store(in: &cancellables)

        client.groupRequests
            .sink { [unowned self] request in
                if let _ = try? dbManager.fetchGroups(.init(id: [request.0.id])).first {
                    return
                }

                if let contact = try! dbManager.fetchContacts(.init(id: [request.0.leaderId])).first {
                    if reportingStatus.isEnabled(), (contact.isBlocked || contact.isBanned) {
                        return
                    }
                }

                DispatchQueue.global().async { [weak self] in
                    self?.processGroupCreation(request.0, memberIds: request.1, welcome: request.2)
                }
            }.store(in: &cancellables)

        client.confirmations
            .sink { [unowned self] in
                if var contact = try? dbManager.fetchContacts(.init(id: [$0.id])).first {
                    contact.authStatus = .friend
                    contact.isRecent = true
                    contact.createdAt = Date()
                    _ = try? dbManager.saveContact(contact)

                    toastController.enqueueToast(model: .init(
                        title: contact.nickname ?? contact.username!,
                        subtitle: Localized.Requests.Confirmations.toaster,
                        leftImage: Asset.sharedSuccess.image
                    ))
                }
            }.store(in: &cancellables)

        client.transfers
            .sink { [unowned self] in
                guard let transfer = try? dbManager.saveFileTransfer($0) else { return }
                handle(incomingTransfer: transfer)
            }
            .store(in: &cancellables)
    }

    func myContact() throws -> Contact {
        if let contact = try dbManager.fetchContacts(.init(id: [client.bindings.myId])).first {
            return contact
        } else {
            return try dbManager.saveContact(.init(id: client.bindings.myId))
        }
    }
}
