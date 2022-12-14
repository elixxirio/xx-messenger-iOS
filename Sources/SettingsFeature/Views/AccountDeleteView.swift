import UIKit
import Shared
import InputField

final class AccountDeleteView: UIView {
    let titleLabel = UILabel()
    let subtitleView = TextWithInfoView()
    let iconImageView = UIImageView()
    let inputField = InputField()

    let stackView = UIStackView()
    let confirmButton = CapsuleButton()
    let cancelButton = CapsuleButton()

    var didTapInfo: (() -> Void)?

    init() {
        super.init(frame: .zero)
        backgroundColor = Asset.neutralWhite.color
        iconImageView.image = Asset.settingsDeleteLarge.image

        iconImageView.contentMode = .center

        inputField.setup(
            style: .regular,
            title: Localized.Settings.Delete.input,
            placeholder: "",
            leftView: .image(Asset.personGray.image),
            subtitleColor: Asset.neutralDisabled.color,
            allowsEmptySpace: false,
            autocapitalization: .none
        )

        titleLabel.text = Localized.Settings.Delete.title
        titleLabel.textAlignment = .center
        titleLabel.textColor = Asset.neutralActive.color
        titleLabel.font = Fonts.Mulish.bold.font(size: 32.0)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineHeightMultiple = 1.1

        subtitleView.setup(
            text: Localized.Settings.Delete.subtitle,
            attributes: [
                .foregroundColor: Asset.neutralActive.color,
                .font: Fonts.Mulish.regular.font(size: 16.0),
                .paragraphStyle: paragraph
            ],
            didTapInfo: { self.didTapInfo?() }
        )

        confirmButton.setStyle(.red)
        confirmButton.isEnabled = false
        confirmButton.setTitle(Localized.Settings.Delete.delete, for: .normal)
        cancelButton.setStyle(.simplestColoredRed)
        cancelButton.setTitle(Localized.Settings.Delete.cancel, for: .normal)

        stackView.spacing = 12
        stackView.axis = .vertical
        stackView.addArrangedSubview(confirmButton)
        stackView.addArrangedSubview(cancelButton)

        addSubview(iconImageView)
        addSubview(inputField)
        addSubview(titleLabel)
        addSubview(subtitleView)
        addSubview(stackView)

        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(30)
            make.centerX.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(34)
            make.centerX.equalToSuperview()
        }

        subtitleView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(50)
            make.right.equalToSuperview().offset(-50)
        }

        inputField.snp.makeConstraints { make in
            make.top.equalTo(subtitleView.snp.bottom).offset(50)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
        }

        stackView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(inputField.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(50)
            make.right.equalToSuperview().offset(-50)
            make.bottom.equalToSuperview().offset(-44)
        }
    }

    required init?(coder: NSCoder) { nil }

    func setInfoClosure(_ closure: @escaping () -> Void) {
        didTapInfo = closure
    }

    func update(username: String) {
        inputField.update(placeholder: username)
    }

    func update(status: InputField.ValidationStatus) {
        inputField.update(status: status)

        switch status {
        case .valid:
            confirmButton.isEnabled = true
        case .invalid, .unknown:
            confirmButton.isEnabled = false
        }
    }
}
