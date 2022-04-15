import UIKit
import Shared
import Models
import Countries
import Presentation

public typealias AttributeControllerClosure = (UIViewController) -> Void

public protocol OnboardingCoordinating {
    func toChats(from: UIViewController)
    func toEmail(from: UIViewController)
    func toPhone(from: UIViewController)
    func toWelcome(from: UIViewController)
    func toStart(with: String, from: UIViewController)
    func toUsername(with: String, from: UIViewController)
    func toPopup(_: UIViewController, from: UIViewController)

    func toSuccess(with: OnboardingSuccessModel, from: UIViewController)
    func toRestoreList(with: String, from: UIViewController)

    func toEmailConfirmation(
        with: AttributeConfirmation,
        from: UIViewController,
        completion: @escaping (UIViewController) -> Void
    )

    func toPhoneConfirmation(
        with: AttributeConfirmation,
        from: UIViewController,
        completion: @escaping (UIViewController) -> Void
    )

    func toCountries(
        from: UIViewController,
        _ onChoose: @escaping (Country) -> Void
    )
}

public struct OnboardingCoordinator: OnboardingCoordinating {
    var pushPresenter: Presenting = PushPresenter()
    var bottomPresenter: Presenting = BottomPresenter()
    var replacePresenter: Presenting = ReplacePresenter()

    var emailFactory: () -> UIViewController
    var phoneFactory: () -> UIViewController
    var welcomeFactory: () -> UIViewController
    var chatListFactory: () -> UIViewController
    var startFactory: (String) -> UIViewController
    var usernameFactory: (String) -> UIViewController
    var restoreListFactory: (String) -> UIViewController
    var successFactory: (OnboardingSuccessModel) -> UIViewController
    var countriesFactory: (@escaping (Country) -> Void) -> UIViewController
    var phoneConfirmationFactory: (AttributeConfirmation, @escaping AttributeControllerClosure) -> UIViewController
    var emailConfirmationFactory: (AttributeConfirmation, @escaping AttributeControllerClosure) -> UIViewController

    public init(
        emailFactory: @escaping () -> UIViewController,
        phoneFactory: @escaping () -> UIViewController,
        welcomeFactory: @escaping () -> UIViewController,
        chatListFactory: @escaping () -> UIViewController,
        startFactory: @escaping (String) -> UIViewController,
        usernameFactory: @escaping (String) -> UIViewController,
        restoreListFactory: @escaping (String) -> UIViewController,
        successFactory: @escaping (OnboardingSuccessModel) -> UIViewController,
        countriesFactory: @escaping (@escaping (Country) -> Void) -> UIViewController,
        phoneConfirmationFactory: @escaping (AttributeConfirmation, @escaping AttributeControllerClosure) -> UIViewController,
        emailConfirmationFactory: @escaping (AttributeConfirmation, @escaping AttributeControllerClosure) -> UIViewController
    ) {
        self.emailFactory = emailFactory
        self.phoneFactory = phoneFactory
        self.startFactory = startFactory
        self.welcomeFactory = welcomeFactory
        self.usernameFactory = usernameFactory
        self.chatListFactory = chatListFactory
        self.restoreListFactory = restoreListFactory
        self.successFactory = successFactory
        self.countriesFactory = countriesFactory
        self.phoneConfirmationFactory = phoneConfirmationFactory
        self.emailConfirmationFactory = emailConfirmationFactory
    }
}

public extension OnboardingCoordinator {
    func toEmail(from parent: UIViewController) {
        let screen = emailFactory()
        replacePresenter.present(screen, from: parent)
    }

    func toPhone(from parent: UIViewController) {
        let screen = phoneFactory()
        replacePresenter.present(screen, from: parent)
    }

    func toChats(from parent: UIViewController) {
        let screen = chatListFactory()
        replacePresenter.present(screen, from: parent)
    }

    func toWelcome(from parent: UIViewController) {
        let screen = welcomeFactory()
        replacePresenter.present(screen, from: parent)
    }

    func toRestoreList(with ndf: String, from parent: UIViewController) {
        let screen = restoreListFactory(ndf)
        pushPresenter.present(screen, from: parent)
    }

    func toSuccess(with model: OnboardingSuccessModel, from parent: UIViewController) {
        let screen = successFactory(model)
        replacePresenter.present(screen, from: parent)
    }

    func toStart(with ndf: String, from parent: UIViewController) {
        let screen = startFactory(ndf)
        replacePresenter.present(screen, from: parent)
    }

    func toUsername(with ndf: String, from parent: UIViewController) {
        let screen = usernameFactory(ndf)
        replacePresenter.present(screen, from: parent)
    }

    func toPopup(_ popup: UIViewController, from parent: UIViewController) {
        bottomPresenter.present(popup, from: parent)
    }

    func toCountries(from parent: UIViewController, _ onChoose: @escaping (Country) -> Void) {
        let screen = countriesFactory(onChoose)
        pushPresenter.present(screen, from: parent)
    }

    func toEmailConfirmation(
        with confirmation: AttributeConfirmation,
        from parent: UIViewController,
        completion: @escaping (UIViewController) -> Void
    ) {
        let screen = emailConfirmationFactory(confirmation, completion)
        pushPresenter.present(screen, from: parent)
    }

    func toPhoneConfirmation(
        with confirmation: AttributeConfirmation,
        from parent: UIViewController,
        completion: @escaping (UIViewController) -> Void
    ) {
        let screen = phoneConfirmationFactory(confirmation, completion)
        pushPresenter.present(screen, from: parent)
    }
}
