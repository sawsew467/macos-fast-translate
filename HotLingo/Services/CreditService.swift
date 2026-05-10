import Foundation

@MainActor
final class CreditService: ObservableObject {
    static let shared = CreditService()

    @Published var balance: Int = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.lastKnownCreditBalance)
    @Published var trialClaimed: Bool = false
    @Published var isLoading = false

    private init() {}

    func fetchBalance() async {
        guard SupabaseAuthService.shared.authState.isLoggedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: BalanceResponse = try await SupabaseClient.shared.request(
                endpoint: "/functions/v1/account-balance"
            )
            balance = response.balance
            trialClaimed = response.trial_claimed
            UserDefaults.standard.set(response.balance, forKey: Constants.UserDefaultsKey.lastKnownCreditBalance)
        } catch {
            print("[CreditService] fetchBalance failed: \(error)")
        }
    }

    func claimTrial() async -> Bool {
        struct ClaimBody: Encodable { let device_id: String }
        do {
            let response: ClaimTrialResponse = try await SupabaseClient.shared.request(
                endpoint: "/functions/v1/account-claim-trial",
                method: "POST",
                body: ClaimBody(device_id: DeviceIdentifier.platformUUID)
            )
            balance = response.balance
            trialClaimed = true
            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKey.hasClaimedTrial)
            return true
        } catch {
            print("[CreditService] claimTrial failed: \(error)")
            return false
        }
    }

    /// Called after each AI translation with remaining_credits from the response.
    func updateBalance(_ newBalance: Int) {
        balance = newBalance
        UserDefaults.standard.set(newBalance, forKey: Constants.UserDefaultsKey.lastKnownCreditBalance)
    }
}
