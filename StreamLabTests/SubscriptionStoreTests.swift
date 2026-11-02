//
//  SubscriptionStoreTests.swift
//  StreamLabTests
//
//  Tests the subscription logic against StreamLab.storekit using SKTestSession.
//

import XCTest
import StoreKit
import StoreKitTest
@testable import StreamLab

@MainActor
final class SubscriptionStoreTests: XCTestCase {
    private var session: SKTestSession!
    private var store: SubscriptionStore!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "StreamLab")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true

        store = SubscriptionStore()
        await store.loadProducts()
        await store.refreshEntitlements()
    }

    override func tearDown() async throws {
        session.clearTransactions()
        session = nil
        store = nil
    }

    // MARK: - Helpers

    private func product(_ id: String) throws -> Product {
        try XCTUnwrap(store.products.first { $0.id == id }, "Product \(id) did not load")
    }

    private func latestTransactionID() throws -> UInt {
        try XCTUnwrap(session.allTransactions().last?.identifier, "No transactions in the session")
    }

    /// Polls until `condition` is true, for changes that arrive asynchronously through the store's listeners.
    private func waitUntil(timeout: TimeInterval = 10, _ message: String, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out waiting: \(message)")
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - Products

    func testProductsLoadInPriceOrderWithTrialOnMonthlyOnly() throws {
        XCTAssertEqual(store.products.map(\.id), [ProductID.monthly, ProductID.annual])

        let intro = try XCTUnwrap(try product(ProductID.monthly).subscription?.introductoryOffer)
        XCTAssertEqual(intro.paymentMode, .freeTrial)
        XCTAssertNil(try product(ProductID.annual).subscription?.introductoryOffer)
    }

    // MARK: - New customer

    func testNewCustomerIsLocked() {
        XCTAssertTrue(store.hasLoadedEntitlements)
        XCTAssertFalse(store.isSubscribed)
        XCTAssertNil(store.details)
        XCTAssertFalse(store.canWatch(isPremium: true))
        XCTAssertTrue(store.canWatch(isPremium: false))
    }

    // MARK: - Purchase

    func testPurchaseUnlocksPremiumWithFreeTrial() async throws {
        let outcome = try await store.purchase(try product(ProductID.monthly))

        XCTAssertEqual(outcome, .success)
        XCTAssertEqual(store.activeProductID, ProductID.monthly)
        XCTAssertTrue(store.canWatch(isPremium: true))
        XCTAssertEqual(store.details?.isFreeTrial, true, "A new customer's first Monthly period is the free trial")
    }

    func testFailedPurchaseKeepsUserLocked() async throws {
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)

        do {
            _ = try await store.purchase(try product(ProductID.monthly))
            XCTFail("Expected the purchase to throw")
        } catch {
            XCTAssertFalse(store.isSubscribed)
        }
    }

    func testAskToBuyIsPendingUntilApproved() async throws {
        session.askToBuyEnabled = true

        let outcome = try await store.purchase(try product(ProductID.monthly))
        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(store.isSubscribed)

        try session.approveAskToBuyTransaction(identifier: try latestTransactionID())
        try await waitUntil("approval unlocks premium") { store.isSubscribed }
    }

    // MARK: - Transaction.updates

    func testRefundRevokesAccess() async throws {
        _ = try await store.purchase(try product(ProductID.monthly))
        XCTAssertTrue(store.isSubscribed)

        try session.refundTransaction(identifier: try latestTransactionID())
        try await waitUntil("refund revokes access") { !store.isSubscribed }
    }

    func testPurchaseMadeOutsideTheAppIsPickedUp() async throws {
        _ = try await session.buyProduct(identifier: ProductID.annual)
        try await waitUntil("outside purchase unlocks premium") { store.activeProductID == ProductID.annual }
    }

    func testRenewalKeepsAccessAndEndsTrial() async throws {
        _ = try await store.purchase(try product(ProductID.monthly))
        XCTAssertEqual(store.details?.isFreeTrial, true)

        try session.forceRenewalOfSubscription(productIdentifier: ProductID.monthly)
        try await waitUntil("renewal starts a paid period") { store.details?.isFreeTrial == false }
        XCTAssertTrue(store.isSubscribed)
    }

    // MARK: - Account details

    func testCancellingTurnsOffAutoRenewButKeepsAccess() async throws {
        _ = try await store.purchase(try product(ProductID.monthly))
        XCTAssertEqual(store.details?.willAutoRenew, true)

        try session.disableAutoRenewForTransaction(identifier: try latestTransactionID())
        try await waitUntil("cancellation shows in details") { store.details?.willAutoRenew == false }
        XCTAssertTrue(store.isSubscribed, "A cancelled subscription keeps access until it expires")
    }

    // MARK: - Restore

    func testRestoreKeepsExistingSubscription() async throws {
        _ = try await store.purchase(try product(ProductID.monthly))

        try await store.restore()
        XCTAssertEqual(store.activeProductID, ProductID.monthly)
    }

    // MARK: - Win-back

    func testLapsedSubscriberIsOfferedWinBack() async throws {
        session.timeRate = .monthlyRenewalEveryThirtySeconds

        _ = try await store.purchase(try product(ProductID.monthly))
        XCTAssertNil(store.winBackOffer, "Active subscribers never see a win-back offer")

        // Cancel, then let the subscription run out on its own.
        try session.disableAutoRenewForTransaction(identifier: try latestTransactionID())
        try await waitUntil(timeout: 30, "the subscription lapses and a win-back offer appears") {
            store.winBackOffer != nil
        }

        XCTAssertFalse(store.isSubscribed, "Content locks once the subscription expires")
        XCTAssertEqual(store.winBackOffer?.offer.id, "winback.monthly.first")
        XCTAssertEqual(store.winBackOffer?.product.id, ProductID.monthly)
    }
}
