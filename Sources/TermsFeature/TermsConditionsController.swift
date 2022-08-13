import UIKit
import Theme
import WebKit
import Shared
import Combine
import Defaults
import DependencyInjection

public final class TermsConditionsController: UIViewController {
    @Dependency var coordinator: TermsCoordinator
    @Dependency var statusBarController: StatusBarStyleControlling

    @KeyObject(.acceptedTerms, defaultValue: false) var didAcceptTerms: Bool

    lazy private var screenView = TermsConditionsView()

    private let ndf: String?
    private var cancellables = Set<AnyCancellable>()

    public init(_ ndf: String?) {
        self.ndf = ndf
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    public override func loadView() {
        view = screenView
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.backButtonTitle = ""
        statusBarController.style.send(.darkContent)
        navigationController?.navigationBar.customize(translucent: true)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        screenView.radioComponent
            .radioButton
            .publisher(for: .touchUpInside)
            .sink { [unowned self] in
                screenView.radioComponent.isEnabled.toggle()
                screenView.nextButton.isEnabled = screenView.radioComponent.isEnabled
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }.store(in: &cancellables)

        screenView.nextButton
            .publisher(for: .touchUpInside)
            .sink { [unowned self] in
                didAcceptTerms = true

                if let ndf = ndf {
                    coordinator.presentUsername(ndf, self)
                } else {
                    coordinator.presentChatList(self)
                }
            }.store(in: &cancellables)

        screenView.showTermsButton
            .publisher(for: .touchUpInside)
            .sink { [unowned self] _ in
                let webView = WKWebView()
                let webController = UIViewController()
                webController.view.addSubview(webView)
                webView.snp.makeConstraints { $0.edges.equalToSuperview() }
                webView.load(URLRequest(url: URL(string: "https://elixxir.io/eula")!))
                present(webController, animated: true)
            }.store(in: &cancellables)
    }
}
