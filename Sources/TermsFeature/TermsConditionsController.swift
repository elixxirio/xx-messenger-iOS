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
        navigationController?.navigationBar.customize(
            translucent: true,
            tint: Asset.neutralWhite.color
        )
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 122/255, green: 235/255, blue: 239/255, alpha: 1).cgColor,
            UIColor(red: 56/255, green: 204/255, blue: 232/255, alpha: 1).cgColor,
            UIColor(red: 63/255, green: 186/255, blue: 253/255, alpha: 1).cgColor,
            UIColor(red: 98/255, green: 163/255, blue: 255/255, alpha: 1).cgColor
        ]

        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)

        gradient.frame = screenView.bounds
        screenView.layer.insertSublayer(gradient, at: 0)
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
