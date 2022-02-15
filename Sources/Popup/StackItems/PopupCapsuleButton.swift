import UIKit
import Shared
import Combine

public final class PopupCapsuleButton: PopupStackItem {
    let model: CapsuleButtonModel

    public var spacingAfter: CGFloat? = 0
    private var cancellables = Set<AnyCancellable>()
    private let actionSubject = PassthroughSubject<Void, Never>()

    public var action: AnyPublisher<Void, Never> { actionSubject.eraseToAnyPublisher() }

    public init(
        model: CapsuleButtonModel,
        spacingAfter: CGFloat? = 10
    ) {
        self.model = model
        self.spacingAfter = spacingAfter
    }

    public func makeView() -> UIView {
        cancellables.removeAll()

        let view = CapsuleButton()
        view.setStyle(model.style)
        view.setTitle(model.title, for: .normal)
        view.accessibilityIdentifier = model.accessibility

        view.publisher(for: .touchUpInside)
            .sink { [weak self] in self?.actionSubject.send() }
            .store(in: &cancellables)

        return view
    }
}
