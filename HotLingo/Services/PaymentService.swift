import Foundation

struct PaymentService {

    func fetchPackages() async throws -> [TopupPackage] {
        let response: PackagesResponse = try await SupabaseClient.shared.request(
            endpoint: "/functions/v1/packages",
            authenticated: false
        )
        return response.packages
    }

    func createQR(packageId: String) async throws -> QRPaymentInfo {
        struct QRBody: Encodable { let package_id: String }
        return try await SupabaseClient.shared.request(
            endpoint: "/functions/v1/payment-create-qr",
            method: "POST",
            body: QRBody(package_id: packageId)
        )
    }
}
