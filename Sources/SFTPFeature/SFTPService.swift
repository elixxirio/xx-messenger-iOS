import UIKit
import Shout
import Socket
import Models
import Combine
import Keychain
import Foundation
import Presentation
import DependencyInjection

public typealias SFTPDownloadResult = (Result<Data, Error>) -> Void
public typealias SFTPAuthorizationParams = (UIViewController, () -> Void)
public typealias SFTPFetchResult = (Result<RestoreSettings?, Error>) -> Void

public struct SFTPService {
    public var isAuthorized: () -> Bool
    public var uploadBackup: (URL) throws -> Void
    public var fetchMetadata: (SFTPFetchResult) -> Void
    public var authorizeFlow: (SFTPAuthorizationParams) -> Void
    public var authenticate: (String, String, String) throws -> Void
    public var downloadBackup: (String, SFTPDownloadResult) -> Void
}

public extension SFTPService {
    static var mock = SFTPService(
        isAuthorized: {
            print("^^^ Requested auth status on sftp service")
            return true
        },
        uploadBackup: { url in
            print("^^^ Requested upload on sftp service")
            print("^^^ URL path: \(url.path)")
        },
        fetchMetadata: { completion in
            print("^^^ Requested backup metadata on sftp service.")
            completion(.success(nil))
        },
        authorizeFlow: { (_, completion) in
            print("^^^ Requested authorizing flow on sftp service.")
            completion()
        },
        authenticate: { host, username, password in
            print("^^^ Requested authentication on sftp service.")
            print("^^^ Host: \(host)")
            print("^^^ Username: \(username)")
            print("^^^ Password: \(password)")
        },
        downloadBackup: { path, completion in
            print("^^^ Requested backup download on sftp service.")
            print("^^^ Path: \(path)")
        }
    )

    static var live = SFTPService(
        isAuthorized: {
            if let keychain = try? DependencyInjection.Container.shared.resolve() as KeychainHandling,
               let pwd = try? keychain.get(key: .pwd),
               let host = try? keychain.get(key: .host),
               let username = try? keychain.get(key: .username) {
                return true
            }

            return false
        },
        uploadBackup: { url in
            let keychain = try DependencyInjection.Container.shared.resolve() as KeychainHandling
            let host = try keychain.get(key: .host)
            let password = try keychain.get(key: .pwd)
            let username = try keychain.get(key: .username)

            let ssh = try SSH(host: host!, port: 22)
            try ssh.authenticate(username: username!, password: password!)
            let sftp = try ssh.openSftp()

            try sftp.upload(localURL: url, remotePath: "backup/backup.xxm")
        },
        fetchMetadata: { completion in
            do {
                let keychain = try DependencyInjection.Container.shared.resolve() as KeychainHandling
                let host = try keychain.get(key: .host)
                let password = try keychain.get(key: .pwd)
                let username = try keychain.get(key: .username)

                let ssh = try SSH(host: host!, port: 22)
                try ssh.authenticate(username: username!, password: password!)
                let sftp = try ssh.openSftp()

                if let files = try? sftp.listFiles(in: "backup"),
                   let backup = files.filter({ file in file.0 == "backup.xxm" }).first {
                    completion(.success(.init(
                        backup: .init(
                            id: "backup/backup.xxm",
                            date: backup.value.lastModified,
                            size: Float(backup.value.size)
                        ),
                        cloudService: .sftp
                    )))

                    return
                }

                completion(.success(nil))
            } catch {
                if let error = error as? SSHError {
                    print(error.kind)
                    print(error.message)
                    print(error.description)
                } else if let error = error as? Socket.Error {
                    print(error.errorCode)
                    print(error.description)
                    print(error.errorReason)
                    print(error.localizedDescription)
                } else {
                    print(error.localizedDescription)
                }

                completion(.failure(error))
            }
        },
        authorizeFlow: { controller, completion in
            var pushPresenter: Presenting = PushPresenter()
            pushPresenter.present(SFTPController(completion), from: controller)
        },
        authenticate: { host, username, password in
            do {
                try SSH.connect(
                    host: host,
                    port: 22,
                    username: username,
                    authMethod: SSHPassword(password)) { ssh in
                        _ = try ssh.openSftp()

                        let keychain = try DependencyInjection.Container.shared.resolve() as KeychainHandling
                        try keychain.store(key: .host, value: host)
                        try keychain.store(key: .pwd, value: password)
                        try keychain.store(key: .username, value: username)
                    }
            } catch {
                if let error = error as? SSHError {
                    print(error.kind)
                    print(error.message)
                    print(error.description)
                } else if let error = error as? Socket.Error {
                    print(error.errorCode)
                    print(error.description)
                    print(error.errorReason)
                    print(error.localizedDescription)
                } else {
                    print(error.localizedDescription)
                }

                throw error
            }
        },
        downloadBackup: { path, completion in
            do {
                let keychain = try DependencyInjection.Container.shared.resolve() as KeychainHandling
                let host = try keychain.get(key: .host)
                let password = try keychain.get(key: .pwd)
                let username = try keychain.get(key: .username)

                let ssh = try SSH(host: host!, port: 22)
                try ssh.authenticate(username: username!, password: password!)
                let sftp = try ssh.openSftp()

                let localURL = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: "group.elixxir.messenger")!
                    .appendingPathComponent("sftp")

                try sftp.download(remotePath: path, localURL: localURL)

                let data = try Data(contentsOf: localURL)
                completion(.success(data))
            } catch {
                completion(.failure(error))

                if var error = error as? SSHError {
                    print(error.kind)
                    print(error.message)
                    print(error.description)
                } else {
                    print(error.localizedDescription)
                }
            }
        }
    )
}
