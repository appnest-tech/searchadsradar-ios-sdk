import Foundation
import StoreKit

/// Listens for StoreKit 2 transactions and sends them to the agent.
/// Captures: purchases, renewals, refunds, revocations — everything.
@available(iOS 16.0, macOS 13.0, *)
final class SARTransactions {
    private let client: SARClient
    private let identity: SARIdentity
    private let appID: String
    private var updateTask: Task<Void, Never>?

    init(client: SARClient, identity: SARIdentity, appID: String) {
        self.client = client
        self.identity = identity
        self.appID = appID
    }

    /// Start listening for transaction updates.
    func startListening() {
        // Send current entitlements on launch (catches renewals/expirations that happened while app was closed)
        Task {
            await sendCurrentEntitlements()
        }

        // Listen for new transactions in real-time
        updateTask = Task(priority: .utility) {
            for await result in Transaction.updates {
                await handleVerificationResult(result, source: "update")
            }
        }

        SARLog.info("Transaction listener started")
    }

    /// Stop listening.
    func stopListening() {
        updateTask?.cancel()
        updateTask = nil
    }

    /// On each launch, iterate current entitlements to catch up on any
    /// renewals, cancellations, or expirations that happened while app was closed.
    private func sendCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            await handleVerificationResult(result, source: "entitlement")
        }
    }

    private func handleVerificationResult(_ result: VerificationResult<Transaction>, source: String) async {
        switch result {
        case .verified(let transaction):
            sendTransaction(transaction, verified: true, source: source)
            await transaction.finish()
        case .unverified(let transaction, let error):
            SARLog.error("Unverified transaction \(transaction.id): \(error)")
            sendTransaction(transaction, verified: false, source: source)
        }
    }

    private func sendTransaction(_ transaction: Transaction, verified: Bool, source: String) {
        let iso8601 = ISO8601DateFormatter()

        var data: [String: AnyCodable] = [
            "transactionID": AnyCodable(Int(transaction.id)),
            "originalTransactionID": AnyCodable(Int(transaction.originalID)),
            "productID": AnyCodable(transaction.productID),
            "productType": AnyCodable(productTypeString(transaction.productType)),
            "purchaseDate": AnyCodable(iso8601.string(from: transaction.purchaseDate)),
            "verified": AnyCodable(verified),
            "source": AnyCodable(source),
            "storefront": AnyCodable(transaction.storefrontCountryCode),
            "quantity": AnyCodable(transaction.purchasedQuantity),
        ]

        // Environment (iOS 16+ / macOS 13+)
        data["environment"] = AnyCodable(environmentString(transaction.environment))

        // Price
        if let price = transaction.price {
            data["price"] = AnyCodable(NSDecimalNumber(decimal: price).doubleValue)
            data["currency"] = AnyCodable(transaction.currency?.identifier ?? "unknown")
        }

        // Subscription-specific
        if let expirationDate = transaction.expirationDate {
            data["expirationDate"] = AnyCodable(iso8601.string(from: expirationDate))
            data["isExpired"] = AnyCodable(expirationDate < Date())
        }
        if let revocationDate = transaction.revocationDate {
            data["revocationDate"] = AnyCodable(iso8601.string(from: revocationDate))
        }
        if let offerType = transaction.offerType {
            data["offerType"] = AnyCodable(offerTypeString(offerType))
        }
        data["isUpgraded"] = AnyCodable(transaction.isUpgraded)

        // JWS — the cryptographic proof, verifiable server-side
        let jsonRep = transaction.jsonRepresentation
        if let jsonString = String(data: jsonRep, encoding: .utf8) {
            data["jwsPayload"] = AnyCodable(jsonString)
        }

        let event = SAREvent(
            type: .transaction,
            appID: appID,
            deviceID: identity.deviceID,
            timestamp: Date(),
            sdkVersion: SARKit.sdkVersion,
            device: identity.deviceInfo,
            data: data
        )
        client.send(event)
        SARLog.info("Sent transaction: \(transaction.productID) (\(source))")
    }

    // MARK: - Helpers

    private func productTypeString(_ type: Product.ProductType) -> String {
        switch type {
        case .autoRenewable: return "autoRenewable"
        case .nonRenewable: return "nonRenewable"
        case .consumable: return "consumable"
        case .nonConsumable: return "nonConsumable"
        default: return "unknown"
        }
    }

    private func environmentString(_ env: AppStore.Environment) -> String {
        switch env {
        case .production: return "production"
        case .sandbox: return "sandbox"
        case .xcode: return "xcode"
        default: return "unknown"
        }
    }

    private func offerTypeString(_ type: Transaction.OfferType) -> String {
        switch type {
        case .introductory: return "introductory"
        case .promotional: return "promotional"
        case .code: return "code"
        default: return "unknown"
        }
    }
}
