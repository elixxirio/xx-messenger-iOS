import Combine
import XXModels
import Defaults
import Foundation
import Integration
import DependencyInjection

final class MenuViewModel {
    @Dependency private var session: SessionType

    @KeyObject(.avatar, defaultValue: nil) var avatar: Data?
    @KeyObject(.username, defaultValue: "") var username: String

    var requestCount: AnyPublisher<Int, Never> {
        let groupQuery = Group.Query(authStatus: [.pending])
        let contactsQuery = Contact.Query(authStatus: [
            .verified,
            .confirming,
            .confirmationFailed,
            .verificationFailed,
            .verificationInProgress
        ])

        return Publishers.CombineLatest(
            session.dbManager.fetchContactsPublisher(contactsQuery).catch { _ in Just([]) },
            session.dbManager.fetchGroupsPublisher(groupQuery).catch { _ in Just([]) }
        )
        .map { $0.0.count + $0.1.count }
        .eraseToAnyPublisher()
    }

    var xxdk: String {
        session.version
    }

    var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
