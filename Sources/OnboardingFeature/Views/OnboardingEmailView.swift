import UIKit
import Shared
import InputField

final class OnboardingEmailView: UIView {
    let titleLabel = UILabel()
    let subtitleView = TextWithInfoView()
    let inputField = InputField()
    let nextButton = CapsuleButton()
    let skipButton = UIButton()
    let stackView = UIStackView()

    var didTapInfo: (() -> Void)?

    init() {
        super.init(frame: .zero)
        backgroundColor = Asset.neutralWhite.color

        setupTitle(Localized.Onboarding.Email.title)
        setupSubtitle(Localized.Onboarding.Email.subtitle)

        inputField.setup(
            placeholder: Localized.Onboarding.Email.input,
            subtitleColor: Asset.neutralWeak.color,
            allowsEmptySpace: false,
            keyboardType: .emailAddress,
            autocapitalization: .none,
            contentType: .emailAddress
        )

        skipButton.titleLabel?.font = Fonts.Mulish.bold.font(size: 14.0)
        skipButton.setTitleColor(Asset.brandPrimary.color, for: .normal)
        skipButton.setTitle(Localized.Onboarding.Email.skip, for: .normal)
        nextButton.set(style: .brandColored, title: Localized.Onboarding.Email.action)
        nextButton.isEnabled = false

        stackView.spacing = 20
        stackView.axis = .vertical
        stackView.addArrangedSubview(nextButton)
        stackView.addArrangedSubview(skipButton)

        addSubview(titleLabel)
        addSubview(subtitleView)
        addSubview(inputField)
        addSubview(stackView)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(30)
            make.left.equalToSuperview().offset(38)
            make.right.equalToSuperview().offset(-41)
        }

        subtitleView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(38)
            make.right.equalToSuperview().offset(-41)
        }

        inputField.snp.makeConstraints { make in
            make.top.equalTo(subtitleView.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(38)
            make.right.equalToSuperview().offset(-38)
        }

        stackView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(inputField.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(40)
            make.right.equalToSuperview().offset(-40)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-50)
        }
    }

    required init?(coder: NSCoder) { nil }

    func update(status: InputField.ValidationStatus) {
        inputField.update(status: status)

        switch status {
        case .valid:
            nextButton.isEnabled = true
        case .invalid, .unknown:
            nextButton.isEnabled = false
        }
    }

    private func setupTitle(_ title: String) {
        let attString = NSMutableAttributedString(string: title)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineHeightMultiple = 1.15

        attString.addAttribute(.paragraphStyle, value: paragraph)
        attString.addAttribute(.foregroundColor, value: Asset.neutralActive.color)
        attString.addAttribute(.font, value: Fonts.Mulish.bold.font(size: 34.0) as Any)

        attString.addAttributes(attributes: [
            .font: Fonts.Mulish.bold.font(size: 34.0) as Any,
            .foregroundColor: Asset.brandPrimary.color
        ], betweenCharacters: "#")

        titleLabel.numberOfLines = 0
        titleLabel.attributedText = attString
    }

    private func setupSubtitle(_ subtitle: String) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineHeightMultiple = 1.15

        subtitleView.setup(
            text: subtitle,
            attributes: [
                .foregroundColor: Asset.neutralBody.color,
                .font: Fonts.Mulish.regular.font(size: 16.0) as Any,
                .paragraphStyle: paragraph
            ],
            didTapInfo: { [weak self] in self?.didTapInfo?() }
        )
    }
}
