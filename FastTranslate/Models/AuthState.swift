import Foundation

enum AuthState: Equatable {
    case loggedOut
    case loading
    case loggedIn(email: String)

    var isLoggedIn: Bool {
        if case .loggedIn = self { return true }
        return false
    }

    var email: String? {
        if case .loggedIn(let email) = self { return email }
        return nil
    }
}
