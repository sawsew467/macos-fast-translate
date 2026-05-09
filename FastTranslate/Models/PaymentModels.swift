import Foundation

struct BalanceResponse: Decodable {
    let balance: Int
    let email: String
    let trial_claimed: Bool
}

struct TopupPackage: Decodable, Identifiable {
    let id: String
    let name: String
    let amount_vnd: Int
    let credits: Int

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return (formatter.string(from: NSNumber(value: amount_vnd)) ?? "\(amount_vnd)") + "đ"
    }
}

struct QRPaymentInfo: Decodable {
    let qr_data: String
    let bank_account: String
    let bank_name: String
    let amount: Int
    let transfer_content: String
    let expires_at: String
}

struct PackagesResponse: Decodable {
    let packages: [TopupPackage]
}

struct ClaimTrialResponse: Decodable {
    let credits_granted: Int
    let balance: Int
}

struct TranslateResponse: Decodable {
    let translated_text: String
    let remaining_credits: Int
}
