import Shared
import Combine
import XXClient
import InputField
import Foundation
import CombineSchedulers
import XXMessengerClient
import CountryListFeature
import DI

final class ProfilePhoneViewModel {
  struct ViewState: Equatable {
    var input: String = ""
    var content: String?
    var confirmationId: String?
    var status: InputField.ValidationStatus = .unknown(nil)
    var country: Country = .fromMyPhone()
  }

  @Dependency var messenger: Messenger
  @Dependency var hudController: HUDController

  var statePublisher: AnyPublisher<ViewState, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  private let stateSubject = CurrentValueSubject<ViewState, Never>(.init())
  private var scheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue.global().eraseToAnyScheduler()

  func didInput(_ string: String) {
    stateSubject.value.input = string
    validate()
  }

  func clearUp() {
    stateSubject.value.confirmationId = nil
  }

  func didChooseCountry(_ country: Country) {
    stateSubject.value.country = country
    validate()
  }

  func didTapNext() {
    hudController.show()
    scheduler.schedule { [weak self] in
      guard let self else { return }
      let content = "\(self.stateSubject.value.input)\(self.stateSubject.value.country.code)"
      do {
        let confirmationId = try self.messenger.ud.get()!.sendRegisterFact(
          .init(type: .phone, value: content)
        )

        self.hudController.dismiss()
        self.stateSubject.value.content = content
        self.stateSubject.value.confirmationId = confirmationId
      } catch {
        let xxError = CreateUserFriendlyErrorMessage.live(error.localizedDescription)
        self.hudController.show(.init(content: xxError))
      }
    }
  }

  private func validate() {
    switch Validator.phone.validate((stateSubject.value.country.regex, stateSubject.value.input)) {
    case .success:
      stateSubject.value.status = .valid(nil)
    case .failure(let error):
      stateSubject.value.status = .invalid(error)
    }
  }
}
