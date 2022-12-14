import UIKit
import Shared
import XXModels

final class Bubbler {
    static func build(
        audioBubble: AudioMessageView,
        with item: Message
    ) {
        audioBubble.dateLabel.text = item.date.asHoursAndMinutes()

        switch item.status {
        case .received:
            audioBubble.lockerImageView.removeFromSuperview()
            audioBubble.backgroundColor = Asset.neutralWhite.color
            audioBubble.dateLabel.textColor = Asset.neutralDisabled.color
            audioBubble.progressLabel.textColor = Asset.neutralDisabled.color
        case .receiving:
            audioBubble.backgroundColor = Asset.neutralWhite.color
            audioBubble.dateLabel.textColor = Asset.neutralDisabled.color
            audioBubble.progressLabel.textColor = Asset.neutralDisabled.color
        case .sendingTimedOut:
            audioBubble.backgroundColor = Asset.accentWarning.color
            audioBubble.dateLabel.textColor = Asset.neutralWhite.color
            audioBubble.progressLabel.textColor = Asset.neutralWhite.color
        case .sendingFailed:
            audioBubble.backgroundColor = Asset.accentDanger.color
            audioBubble.dateLabel.textColor = Asset.neutralWhite.color
            audioBubble.progressLabel.textColor = Asset.neutralWhite.color
        case .sent:
            audioBubble.backgroundColor = Asset.brandBubble.color
            audioBubble.dateLabel.textColor = Asset.neutralWhite.color
            audioBubble.progressLabel.textColor = Asset.neutralWhite.color
        case .sending:
            audioBubble.backgroundColor = Asset.brandBubble.color
            audioBubble.dateLabel.textColor = Asset.neutralWhite.color
            audioBubble.progressLabel.textColor = Asset.neutralWhite.color
        case .receivingFailed:
            audioBubble.backgroundColor = Asset.accentWarning.color
            audioBubble.dateLabel.textColor = Asset.neutralWhite.color
            audioBubble.progressLabel.textColor = Asset.neutralWhite.color
        }
    }

    static func build(
        imageBubble: ImageMessageView,
        with message: Message,
        with transfer: FileTransfer
    ) {
        imageBubble.progressLabel.text = String(format: "%.1f%%", transfer.progress * 100)
        imageBubble.dateLabel.text = message.date.asHoursAndMinutes()

        switch message.status {
        case .received:
            imageBubble.lockerImageView.removeFromSuperview()
            imageBubble.backgroundColor = Asset.neutralWhite.color
            imageBubble.dateLabel.textColor = Asset.neutralDisabled.color
            imageBubble.progressLabel.textColor = Asset.neutralDisabled.color
        case .receiving:
            imageBubble.backgroundColor = Asset.neutralWhite.color
            imageBubble.dateLabel.textColor = Asset.neutralDisabled.color
            imageBubble.progressLabel.textColor = Asset.neutralDisabled.color
        case .sendingFailed:
            imageBubble.backgroundColor = Asset.accentDanger.color
            imageBubble.dateLabel.textColor = Asset.neutralWhite.color
            imageBubble.progressLabel.textColor = Asset.neutralWhite.color
        case .sendingTimedOut:
            imageBubble.backgroundColor = Asset.accentWarning.color
            imageBubble.dateLabel.textColor = Asset.neutralWhite.color
            imageBubble.progressLabel.textColor = Asset.neutralWhite.color
        case .sent:
            imageBubble.backgroundColor = Asset.brandBubble.color
            imageBubble.dateLabel.textColor = Asset.neutralWhite.color
            imageBubble.progressLabel.textColor = Asset.neutralWhite.color
        case .sending:
            imageBubble.backgroundColor = Asset.brandBubble.color
            imageBubble.dateLabel.textColor = Asset.neutralWhite.color
            imageBubble.progressLabel.textColor = Asset.neutralWhite.color
        case .receivingFailed:
            imageBubble.backgroundColor = Asset.accentWarning.color
            imageBubble.dateLabel.textColor = Asset.neutralWhite.color
            imageBubble.progressLabel.textColor = Asset.neutralWhite.color
        }
    }

    static func build(
        bubble: StackMessageView,
        with item: Message
    ) {
        bubble.textView.text = item.text
        bubble.senderLabel.removeFromSuperview()
        bubble.dateLabel.text = item.date.asHoursAndMinutes()

        let roundButtonColor: UIColor

        switch item.status {
        case .received, .receiving:
            bubble.lockerImageView.removeFromSuperview()
            bubble.backgroundColor = Asset.neutralWhite.color
            bubble.textView.textColor = Asset.neutralActive.color
            bubble.dateLabel.textColor = Asset.neutralDisabled.color
            roundButtonColor = Asset.neutralDisabled.color
            bubble.revertBottomStackOrder()
        case .sendingTimedOut:
            bubble.backgroundColor = Asset.accentWarning.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
        case .sendingFailed:
            bubble.backgroundColor = Asset.accentDanger.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
        case .sent:
            bubble.backgroundColor = Asset.brandBubble.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
        case .sending:
            bubble.backgroundColor = Asset.brandBubble.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
        case .receivingFailed:
            bubble.backgroundColor = Asset.accentWarning.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
        }

        let attrString = NSAttributedString(
            string: "show mix",
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: roundButtonColor,
                .foregroundColor: roundButtonColor,
                .font: Fonts.Mulish.regular.font(size: 12.0) as Any
            ]
        )

        bubble.roundButton.setAttributedTitle(attrString, for: .normal)
    }

    static func buildReply(
        bubble: ReplyStackMessageView,
        with item: Message,
        reply: (contactTitle: String, messageText: String)
    ) {
        bubble.dateLabel.text = item.date.asHoursAndMinutes()
        bubble.textView.text = item.text

        bubble.replyView.message.text = reply.messageText
        bubble.replyView.title.text = reply.contactTitle

        let roundButtonColor: UIColor

        switch item.status {
        case .received, .receiving:
            bubble.senderLabel.removeFromSuperview()
            bubble.backgroundColor = Asset.neutralWhite.color
            bubble.textView.textColor = Asset.neutralActive.color
            bubble.dateLabel.textColor = Asset.neutralDisabled.color
            roundButtonColor = Asset.neutralDisabled.color
            bubble.replyView.container.backgroundColor = Asset.brandDefault.color
            bubble.replyView.space.backgroundColor = Asset.brandPrimary.color
            bubble.revertBottomStackOrder()
        case .sendingTimedOut:
            bubble.senderLabel.removeFromSuperview()
            bubble.backgroundColor = Asset.accentWarning.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
            bubble.replyView.space.backgroundColor = Asset.neutralWhite.color
            bubble.replyView.container.backgroundColor = Asset.brandLight.color
        case .sendingFailed:
            bubble.senderLabel.removeFromSuperview()
            bubble.backgroundColor = Asset.accentDanger.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
            bubble.replyView.space.backgroundColor = Asset.neutralWhite.color
            bubble.replyView.container.backgroundColor = Asset.brandLight.color
        case .sent, .sending:
            bubble.senderLabel.removeFromSuperview()
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.backgroundColor = Asset.brandBubble.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
            bubble.replyView.space.backgroundColor = Asset.neutralWhite.color
            bubble.replyView.container.backgroundColor = Asset.brandLight.color
        case .receivingFailed:
            bubble.senderLabel.removeFromSuperview()
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.backgroundColor = Asset.accentWarning.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
            bubble.replyView.space.backgroundColor = Asset.neutralWhite.color
            bubble.replyView.container.backgroundColor = Asset.brandLight.color
        }

        let attrString = NSAttributedString(
            string: "show mix",
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: roundButtonColor,
                .foregroundColor: roundButtonColor,
                .font: Fonts.Mulish.regular.font(size: 12.0) as Any
            ]
        )
        bubble.roundButton.setAttributedTitle(attrString, for: .normal)
    }

    static func buildReplyGroup(
        bubble: ReplyStackMessageView,
        with item: Message,
        reply: (contactTitle: String, messageText: String),
        sender: String
    ) {
        bubble.dateLabel.text = item.date.asHoursAndMinutes()
        bubble.textView.text = item.text

        bubble.replyView.message.text = reply.messageText
        bubble.replyView.title.text = reply.contactTitle

        let roundButtonColor: UIColor

        switch item.status {
        case .received, .receiving:
            bubble.senderLabel.text = sender
            bubble.backgroundColor = Asset.neutralWhite.color
            bubble.textView.textColor = Asset.neutralActive.color
            bubble.dateLabel.textColor = Asset.neutralDisabled.color
            roundButtonColor = Asset.neutralDisabled.color
            bubble.replyView.container.backgroundColor = Asset.brandDefault.color
            bubble.replyView.space.backgroundColor = Asset.brandPrimary.color
            bubble.lockerImageView.removeFromSuperview()
            bubble.revertBottomStackOrder()
        case .sendingFailed, .sendingTimedOut:
            bubble.senderLabel.removeFromSuperview()
            bubble.backgroundColor = Asset.accentDanger.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
            bubble.replyView.space.backgroundColor = Asset.neutralWhite.color
            bubble.replyView.container.backgroundColor = Asset.brandLight.color
        case .sent, .sending:
            bubble.senderLabel.removeFromSuperview()
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.backgroundColor = Asset.brandBubble.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
            bubble.replyView.space.backgroundColor = Asset.neutralWhite.color
            bubble.replyView.container.backgroundColor = Asset.brandLight.color
        case .receivingFailed:
            bubble.senderLabel.removeFromSuperview()
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.backgroundColor = Asset.accentWarning.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
            bubble.replyView.space.backgroundColor = Asset.neutralWhite.color
            bubble.replyView.container.backgroundColor = Asset.brandLight.color
        }

        let attrString = NSAttributedString(
            string: "show mix",
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: roundButtonColor,
                .foregroundColor: roundButtonColor,
                .font: Fonts.Mulish.regular.font(size: 12.0) as Any
            ]
        )

        bubble.roundButton.setAttributedTitle(attrString, for: .normal)
    }

    static func buildGroup(
        bubble: StackMessageView,
        with item: Message,
        with senderName: String
    ) {
        bubble.textView.text = item.text
        bubble.dateLabel.text = item.date.asHoursAndMinutes()

        let roundButtonColor: UIColor

        switch item.status {
        case .received, .receiving:
            bubble.senderLabel.text = senderName
            bubble.backgroundColor = Asset.neutralWhite.color
            bubble.textView.textColor = Asset.neutralActive.color
            bubble.dateLabel.textColor = Asset.neutralDisabled.color
            roundButtonColor = Asset.neutralDisabled.color
            bubble.lockerImageView.removeFromSuperview()
            bubble.revertBottomStackOrder()
        case .sendingFailed, .sendingTimedOut:
            bubble.senderLabel.removeFromSuperview()
            bubble.backgroundColor = Asset.accentDanger.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
        case .sent, .sending:
            bubble.senderLabel.removeFromSuperview()
            bubble.backgroundColor = Asset.brandBubble.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
        case .receivingFailed:
            bubble.senderLabel.removeFromSuperview()
            bubble.backgroundColor = Asset.accentWarning.color
            bubble.textView.textColor = Asset.neutralWhite.color
            bubble.dateLabel.textColor = Asset.neutralWhite.color
            roundButtonColor = Asset.neutralWhite.color
        }

        let attrString = NSAttributedString(
            string: "show mix",
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: roundButtonColor,
                .foregroundColor: roundButtonColor,
                .font: Fonts.Mulish.regular.font(size: 12.0) as Any
            ]
        )

        bubble.roundButton.setAttributedTitle(attrString, for: .normal)
    }


}
