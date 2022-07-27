import HUD
import UIKit
import Shared
import Combine
import XXModels
import Defaults
import Countries
import DrawerFeature
import CollectionView
import DependencyInjection

final class SearchLeftController: UIViewController {
    @Dependency private var hud: HUD
    @Dependency private var coordinator: SearchCoordinating

    @KeyObject(.email, defaultValue: nil) var email: String?
    @KeyObject(.phone, defaultValue: nil) var phone: String?
    @KeyObject(.sharingEmail, defaultValue: false) var isSharingEmail: Bool
    @KeyObject(.sharingPhone, defaultValue: false) var isSharingPhone: Bool

    lazy private var screenView = SearchLeftView()

    private(set) var viewModel = SearchLeftViewModel()
    private var drawerCancellables = Set<AnyCancellable>()
    private let adrpURLString = "https://links.xx.network/adrp"
    private var dataSource: UICollectionViewDiffableDataSource<SearchSection, SearchItem>!

    private var cancellables = Set<AnyCancellable>()
    private var hudCancellables = Set<AnyCancellable>()

    override func loadView() {
        view = screenView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupBindings()
    }

    func endEditing() {
        screenView.inputField.endEditing(true)
    }

    private func setupCollectionView() {
        screenView.collectionView.delegate = self
        screenView.collectionView.dataSource = dataSource

        CellFactory.avatarCellFactory(resend: { _ in })
            .register(in: screenView.collectionView)

        screenView.collectionView
            .registerSectionHeader(SearchLeftSectionHeader.self)

        dataSource = UICollectionViewDiffableDataSource<SearchSection, SearchItem>(
            collectionView: screenView.collectionView
        ) { collectionView, indexPath, searchItem in
            CellFactory.avatarCellFactory { [weak self] in
                guard let self = self else { return }
                self.viewModel.didTapResend(contact: $0)
            }.build(for: searchItem, in: collectionView, at: indexPath)
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }

            let sectionIdentifier = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            let sectionView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: String(describing: SearchLeftSectionHeader.self),
                for: indexPath
            )

            if let sectionView = sectionView as? SearchLeftSectionHeader, case .connections = sectionIdentifier {
                sectionView.set(title: Localized.Ud.localResults)
            }

            return sectionView
        }
    }

    private func setupBindings() {
        viewModel.hudPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                hud.update(with: $0)

                if case .onAction = $0, let hudBtn = hud.actionButton {
                    hudBtn.publisher(for: .touchUpInside)
                        .receive(on: DispatchQueue.main)
                        .sink { [unowned self] in viewModel.didTapCancelSearch() }
                        .store(in: &self.hudCancellables)
                } else {
                    hudCancellables.removeAll()
                }
            }
            .store(in: &cancellables)


        viewModel.statePublisher
            .map(\.item)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in screenView.updateUIForItem(item: $0) }
            .store(in: &cancellables)

        viewModel.statePublisher
            .map(\.country)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in screenView.countryButton.setFlag($0.flag, prefix: $0.prefix) }
            .store(in: &cancellables)

        viewModel.statePublisher
            .compactMap(\.snapshot)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                screenView.placeholderView.isHidden = true
                screenView.emptyView.isHidden = $0.numberOfItems != 0

                dataSource.apply($0, animatingDifferences: false)
            }.store(in: &cancellables)

        screenView.placeholderView
            .infoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in presentSearchDisclaimer() }
            .store(in: &cancellables)

        screenView.countryButton
            .publisher(for: .touchUpInside)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                coordinator.toCountries(from: self) { [weak self] country in
                    guard let self = self else { return }
                    self.viewModel.didPick(country: country)
                }
            }.store(in: &cancellables)

        screenView.inputField
            .textPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in viewModel.didEnterInput($0) }
            .store(in: &cancellables)

        screenView.inputField
            .returnPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] _ in viewModel.didStartSearching() }
            .store(in: &cancellables)

        screenView.inputField
            .isEditingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] isEditing in
                UIView.animate(withDuration: 0.25) {
                    self.screenView.placeholderView.titleLabel.alpha = isEditing ? 0.1 : 1.0
                    self.screenView.placeholderView.subtitleWithInfo.alpha = isEditing ? 0.1 : 1.0
                }
            }.store(in: &cancellables)

        viewModel.successPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in presentSucessDrawerFor(contact: $0) }
            .store(in: &cancellables)
    }

    private func presentSearchDisclaimer() {
        let actionButton = CapsuleButton()
        actionButton.set(
            style: .seeThrough,
            title: Localized.Ud.Placeholder.Drawer.action
        )

        let drawer = DrawerController(with: [
            DrawerText(
                font: Fonts.Mulish.bold.font(size: 26.0),
                text: Localized.Ud.Placeholder.Drawer.title,
                color: Asset.neutralActive.color,
                alignment: .left,
                spacingAfter: 19
            ),
            DrawerLinkText(
                text: Localized.Ud.Placeholder.Drawer.subtitle,
                urlString: adrpURLString,
                spacingAfter: 37
            ),
            DrawerStack(views: [
                actionButton,
                FlexibleSpace()
            ])
        ])

        actionButton.publisher(for: .touchUpInside)
            .receive(on: DispatchQueue.main)
            .sink {
                drawer.dismiss(animated: true) { [weak self] in
                    guard let self = self else { return }
                    self.drawerCancellables.removeAll()
                }
            }.store(in: &self.drawerCancellables)

        coordinator.toDrawer(drawer, from: self)
    }

    private func presentSucessDrawerFor(contact: Contact) {
        var items: [DrawerItem] = []

        let drawerTitle = DrawerText(
            font: Fonts.Mulish.extraBold.font(size: 26.0),
            text: Localized.Ud.NicknameDrawer.title,
            color: Asset.neutralDark.color,
            spacingAfter: 20
        )

        let drawerSubtitle = DrawerText(
            font: Fonts.Mulish.regular.font(size: 16.0),
            text: Localized.Ud.NicknameDrawer.subtitle,
            color: Asset.neutralDark.color,
            spacingAfter: 20
        )

        items.append(contentsOf: [
            drawerTitle,
            drawerSubtitle
        ])

        let drawerNicknameInput = DrawerInput(
            placeholder: contact.username!,
            validator: .init(
                wrongIcon: .image(Asset.sharedError.image),
                correctIcon: .image(Asset.sharedSuccess.image),
                shouldAcceptPlaceholder: true
            ),
            spacingAfter: 29
        )

        items.append(drawerNicknameInput)

        let drawerSaveButton = DrawerCapsuleButton(
            model: .init(
                title: Localized.Ud.NicknameDrawer.save,
                style: .brandColored
            ), spacingAfter: 5
        )

        items.append(drawerSaveButton)

        let drawer = DrawerController(with: items)
        var nickname: String?
        var allowsSave = true

        drawerNicknameInput.validationPublisher
            .receive(on: DispatchQueue.main)
            .sink { allowsSave = $0 }
            .store(in: &drawerCancellables)

        drawerNicknameInput.inputPublisher
            .receive(on: DispatchQueue.main)
            .sink {
                guard !$0.isEmpty else {
                    nickname = contact.username
                    return
                }

                nickname = $0
            }
            .store(in: &drawerCancellables)

        drawerSaveButton.action
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                guard allowsSave else { return }

                drawer.dismiss(animated: true) {
                    self.viewModel.didSet(nickname: nickname ?? contact.username!, for: contact)
                }
            }
            .store(in: &drawerCancellables)

        coordinator.toNicknameDrawer(drawer, from: self)
    }

    private func presentRequestDrawer(forContact contact: Contact) {
        var items: [DrawerItem] = []

        let drawerTitle = DrawerText(
            font: Fonts.Mulish.extraBold.font(size: 26.0),
            text: Localized.Ud.RequestDrawer.title,
            color: Asset.neutralDark.color,
            spacingAfter: 20
        )

        var subtitleFragment = "Share your information with #\(contact.username ?? "")"

        if let email = contact.email {
            subtitleFragment.append(contentsOf: " (\(email))#")
        } else if let phone = contact.phone {
            subtitleFragment.append(contentsOf: " (\(Country.findFrom(phone).prefix) \(phone.dropLast(2)))#")
        } else {
            subtitleFragment.append(contentsOf: "#")
        }

        subtitleFragment.append(contentsOf: " so they know its you.")

        let drawerSubtitle = DrawerText(
            font: Fonts.Mulish.regular.font(size: 16.0),
            text: subtitleFragment,
            color: Asset.neutralDark.color,
            spacingAfter: 31.5,
            customAttributes: [
                .font: Fonts.Mulish.regular.font(size: 16.0) as Any,
                .foregroundColor: Asset.brandPrimary.color
            ]
        )

        items.append(contentsOf: [
            drawerTitle,
            drawerSubtitle
        ])

        if let email = email {
            let drawerEmail = DrawerSwitch(
                title: Localized.Ud.RequestDrawer.email,
                content: email,
                spacingAfter: phone != nil ? 23 : 31,
                isInitiallyOn: isSharingEmail
            )

            items.append(drawerEmail)

            drawerEmail.isOnPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.isSharingEmail = $0 }
                .store(in: &drawerCancellables)
        }

        if let phone = phone {
            let drawerPhone = DrawerSwitch(
                title: Localized.Ud.RequestDrawer.phone,
                content: "\(Country.findFrom(phone).prefix) \(phone.dropLast(2))",
                spacingAfter: 31,
                isInitiallyOn: isSharingPhone
            )

            items.append(drawerPhone)

            drawerPhone.isOnPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.isSharingPhone = $0 }
                .store(in: &drawerCancellables)
        }

        let drawerSendButton = DrawerCapsuleButton(
            model: .init(
                title: Localized.Ud.RequestDrawer.send,
                style: .brandColored
            ), spacingAfter: 5
        )

        let drawerCancelButton = DrawerCapsuleButton(
            model: .init(
                title: Localized.Ud.RequestDrawer.cancel,
                style: .simplestColoredBrand
            ), spacingAfter: 5
        )

        items.append(contentsOf: [drawerSendButton, drawerCancelButton])
        let drawer = DrawerController(with: items)

        drawerSendButton.action
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                drawer.dismiss(animated: true) {
                    self.viewModel.didTapRequest(contact: contact)
                }
            }.store(in: &drawerCancellables)

        drawerCancelButton.action
            .receive(on: DispatchQueue.main)
            .sink { drawer.dismiss(animated: true) }
            .store(in: &drawerCancellables)

        coordinator.toDrawer(drawer, from: self)
    }

}

extension SearchLeftController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let item = dataSource.itemIdentifier(for: indexPath) {
            switch item {
            case .stranger(let contact):
                didTap(contact: contact)
            case .connection(let contact):
                didTap(contact: contact)
            }
        }
    }

    private func didTap(contact: Contact) {
        guard contact.authStatus == .stranger else {
            coordinator.toContact(contact, from: self)
            return
        }

        presentRequestDrawer(forContact: contact)
    }
}

extension CellFactory where Model == SearchItem {
    static func avatarCellFactory(resend: @escaping (Contact) -> Void) -> Self {
        .init(
            register: .init { $0.register(AvatarCell.self) },
            build: .init { searchItem, collectionView, indexPath in
                let contact: Contact
                let cell: AvatarCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)

                let h1Text: String
                var h2Text: String?

                switch searchItem {
                case .stranger(let stranger):
                    contact = stranger
                    h1Text = stranger.username ?? ""

                    if stranger.authStatus == .requested {
                        h2Text = "Request pending"
                    } else if stranger.authStatus == .requestFailed {
                        h2Text = "Request failed"
                    }

                case .connection(let connection):
                    contact = connection
                    h1Text = (connection.nickname ?? contact.username) ?? ""

                    if connection.nickname != nil {
                        h2Text = contact.username ?? ""
                    }
                }

                var action: AvatarCell.Action?

                if contact.authStatus == .requested {
                    action = .init(
                        title: Localized.Requests.Cell.requested,
                        color: Asset.brandPrimary.color,
                        image: Asset.requestsResend.image,
                        action: {
                            resend(contact)

                            cell.update(action: .init(
                                title: Localized.Requests.Cell.resent,
                                color: Asset.neutralWeak.color,
                                image: Asset.requestsResent.image,
                                action: {}
                            ))
                        }
                    )
                }

                cell.set(
                    image: contact.photo,
                    h1Text: h1Text,
                    h2Text: h2Text,
                    h3Text: contact.email,
                    h4Text: contact.phone,
                    showSeparator: false,
                    action: action
                )

                return cell
            }
        )
    }
}
