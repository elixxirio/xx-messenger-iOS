import HUD
import UIKit
import Shared
import Combine
import Defaults
import Countries
import Foundation
import Permissions
import Integration
import CombineSchedulers
import DependencyInjection

enum ProfileNavigationRoutes {
    case none
    case library
    case libraryPermission
}

struct ProfileViewState: Equatable {
    var email: String?
    var phone: String?
    var photo: UIImage?
}

final class ProfileViewModel {
    @KeyObject(.avatar, defaultValue: nil) var avatar: Data?
    @KeyObject(.email, defaultValue: nil) var emailStored: String?
    @KeyObject(.phone, defaultValue: nil) var phoneStored: String?
    @KeyObject(.username, defaultValue: nil) var username: String?
    @KeyObject(.sharingEmail, defaultValue: false) var isEmailSharing: Bool
    @KeyObject(.sharingPhone, defaultValue: false) var isPhoneSharing: Bool

    @Dependency private var session: SessionType
    @Dependency private var permissions: PermissionHandling

    var name: String { username! }

    var state: AnyPublisher<ProfileViewState, Never> { stateRelay.eraseToAnyPublisher() }
    private let stateRelay = CurrentValueSubject<ProfileViewState, Never>(.init())

    var hud: AnyPublisher<HUDStatus, Never> { hudRelay.eraseToAnyPublisher() }
    private let hudRelay = CurrentValueSubject<HUDStatus, Never>(.none)

    var navigation: AnyPublisher<ProfileNavigationRoutes, Never> { navigationRoutes.eraseToAnyPublisher() }
    private let navigationRoutes = PassthroughSubject<ProfileNavigationRoutes, Never>()

    var backgroundScheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue.global().eraseToAnyScheduler()

    init() {
        refresh()
    }

    func refresh() {
        var cleanPhone = phoneStored

        if let phone = cleanPhone {
            let country = Country.findFrom(phone)
            cleanPhone = "\(country.prefix)\(phone.dropLast(2))"
        }

        stateRelay.value = .init(
            email: emailStored,
            phone: cleanPhone,
            photo: avatar != nil ? UIImage(data: avatar!) : nil
        )
    }

    func didRequestLibraryAccess() {
        if permissions.isPhotosAllowed {
            navigationRoutes.send(.library)
        } else {
            navigationRoutes.send(.libraryPermission)
        }
    }

    func didNavigateSomewhere() {
        navigationRoutes.send(.none)
    }

    func didChoosePhoto(_ photo: UIImage) {
        stateRelay.value.photo = photo
        avatar = photo.jpegData(compressionQuality: 0.0)
    }

    func didTapDelete(isEmail: Bool) {
        hudRelay.send(.on)

        backgroundScheduler.schedule { [weak self] in
            guard let self = self else { return }

            do {
                try self.session.unregister(fact: isEmail ? .email : .phone)

                self.hudRelay.send(.none)
                self.refresh()
            } catch {
                self.hudRelay.send(.error(.init(with: error)))
            }
        }
    }
}
