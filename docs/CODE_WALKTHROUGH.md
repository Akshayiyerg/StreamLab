# StreamLab code walkthrough

A line-by-line explanation of every file in StreamLab: what each line does and why it's there. Files are in the order the app uses them: launch, the subscription store, the catalogue, the screens, then the tests.

Each file is shown in small blocks. Under each block, every line (or group of closely related lines) is explained. Where something could be improved, it's marked **Note**.

**Every file starts with the same Xcode header**, for example:

```swift
//
//  SubscriptionStore.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-09.
//
```

These are comments (`//`). The compiler ignores them. Xcode adds them when a file is created. They're not repeated below.

## Contents

1. [App/StreamLabApp.swift](#1-appstreamlabappswift)
2. [App/RootView.swift](#2-approotviewswift)
3. [Store/ProductID.swift](#3-storeproductidswift)
4. [Store/SubscriptionStore.swift](#4-storesubscriptionstoreswift)
5. [Store/Product+Paywall.swift](#5-storeproductpaywallswift)
6. [Shared/AppLinks.swift](#6-sharedapplinksswift)
7. [Catalog/Video.swift](#7-catalogvideoswift)
8. [Catalog/CachedVideo.swift](#8-catalogcachedvideoswift)
9. [Catalog/CatalogService.swift](#9-catalogcatalogserviceswift)
10. [Catalog/CatalogRepository.swift](#10-catalogcatalogrepositoryswift)
11. [Features/Home/HomeView.swift](#11-featureshomehomeviewswift)
12. [Features/Home/PosterView.swift](#12-featureshomeposterviewswift)
13. [Features/Home/VideoDetailView.swift](#13-featureshomevideodetailviewswift)
14. [Features/Player/PlayerView.swift](#14-featuresplayerplayerviewswift)
15. [Features/Paywall/PaywallStyle.swift](#15-featurespaywallpaywallstyleswift)
16. [Features/Paywall/PaywallView.swift](#16-featurespaywallpaywallviewswift)
17. [Features/Paywall/StoreKitPaywallView.swift](#17-featurespaywallstorekitpaywallviewswift)
18. [Features/Paywall/WinBackOfferView.swift](#18-featurespaywallwinbackofferviewswift)
19. [Features/Account/AccountView.swift](#19-featuresaccountaccountviewswift)
20. [StreamLabTests/SubscriptionStoreTests.swift](#20-streamlabtestssubscriptionstoretestsswift)
21. [StreamLabTests/StreamLabTests.swift](#21-streamlabtestsstreamlabtestsswift)
22. [Resources and other files](#22-resources-and-other-files)
23. [Review notes](#23-review-notes)

---

## 1. App/StreamLabApp.swift

The entry point. It creates the one subscription store and the database, and shows the first screen.

```swift
import SwiftUI
import SwiftData
```

- `import SwiftUI`: brings in SwiftUI, Apple's framework for building the UI (`App`, `Scene`, `WindowGroup`, views).
- `import SwiftData`: brings in SwiftData, needed here for `.modelContainer`, which creates the database for the catalogue cache.

```swift
@main
struct StreamLabApp: App {
```

- `@main`: marks this type as the program's starting point. When iOS launches the app, it starts here. Only one type in an app can have it.
- `struct StreamLabApp: App`: declares the app itself. Conforming to the `App` protocol means it must provide a `body` describing its scenes (windows).

```swift
    @State private var store = SubscriptionStore()
```

- Creates the **single** `SubscriptionStore` for the whole app.
- `@State` tells SwiftUI to own this object and keep it alive for the app's lifetime. Without it, a new store could be created each time SwiftUI rebuilds `StreamLabApp`, losing its state and starting extra listeners.
- `private`: only this type can touch the property directly. Other code receives the store through the environment (below).

```swift
    var body: some Scene {
        WindowGroup {
            RootView()
```

- `var body: some Scene`: what the app shows. `some Scene` means "a specific scene type that Swift works out".
- `WindowGroup`: the standard window for an iOS app. On iPad it can open several windows; each would show `RootView`.
- `RootView()`: the first view, the tab bar.

```swift
                .environment(store)
```

- Puts the store into SwiftUI's **environment**, so every view below `RootView` can read it with `@Environment(SubscriptionStore.self)`. This avoids passing it through every initialiser by hand.

```swift
                .task {
                    await store.loadProducts()
                    await store.refreshEntitlements()
                }
```

- `.task`: runs this async work when `RootView` first appears, and cancels it if the view goes away.
- `loadProducts()` first: fetches the Monthly and Annual products from StoreKit.
- `refreshEntitlements()` second: works out whether the user is subscribed. It comes after products because trial eligibility and the Account screen's plan names need the products.

```swift
        }
        .modelContainer(for: CachedVideo.self)
    }
}
```

- `.modelContainer(for: CachedVideo.self)`: creates (first launch) or opens (later launches) the SwiftData database that stores `CachedVideo` records. It also puts a `ModelContext` into the environment, which `HomeView` uses.
- It's attached to the `WindowGroup`, so every window shares one database.

---

## 2. App/RootView.swift

The tab bar with Home and Account.

```swift
import SwiftUI
import SwiftData
```

- `SwiftUI` for the views.
- `SwiftData` is only needed by the `#Preview` at the bottom, which creates an in-memory database.

```swift
struct RootView: View {
    var body: some View {
        TabView {
```

- `struct RootView: View`: a SwiftUI view. Its `body` describes what to draw.
- `TabView`: the bottom tab bar container.

```swift
            Tab("Home", systemImage: "play.rectangle.fill") {
                HomeView()
            }
            Tab("Account", systemImage: "person.crop.circle") {
                AccountView()
            }
```

- `Tab(_:systemImage:)`: the iOS 18 way to declare a tab, with a title and an SF Symbol icon. The closure is the tab's content.
- Each tab's view has its own `NavigationStack` inside, so each keeps its own navigation history when you switch tabs.

```swift
        }
    }
}

#Preview {
    RootView()
        .environment(SubscriptionStore())
        .modelContainer(for: CachedVideo.self, inMemory: true)
}
```

- `#Preview`: what Xcode's canvas shows. It isn't part of the running app.
- `.environment(SubscriptionStore())`: the views below read the store from the environment, so the preview must supply one or it crashes.
- `.modelContainer(..., inMemory: true)`: `HomeView` uses `@Query`, which needs a database. `inMemory: true` makes a temporary one that's never saved to disk.

---

## 3. Store/ProductID.swift

The product IDs, in one place.

```swift
enum ProductID {
```

- An `enum` with **no cases**. You can't create an instance of it, so it acts purely as a namespace for constants. This is a common Swift idiom.

```swift
    static let monthly = "com.akshay.StreamLab.premium.monthly"
    static let annual = "com.akshay.StreamLab.premium.annual"
```

- The two product IDs. They must match `StreamLab.storekit` (and App Store Connect in a real app) exactly.
- `static`: belongs to the type, so you write `ProductID.monthly`.
- Keeping them here means a typo can only happen once, not in every file that needs an ID.

```swift
    static let all = [monthly, annual]
}
```

- Both IDs as an array, passed to `Product.products(for:)` and `SubscriptionStoreView(productIDs:)`.

---

## 4. Store/SubscriptionStore.swift

The heart of the app. All StoreKit code lives here; views only read its state and call its methods.

### Imports

```swift
import StoreKit
import Observation
```

- `StoreKit`: Apple's in-app purchase framework (`Product`, `Transaction`, `AppStore`).
- `Observation`: provides the `@Observable` macro used on the class.

### `SubscriptionDetails`

```swift
struct SubscriptionDetails {
    let productID: String
    let state: Product.SubscriptionInfo.RenewalState
    let expirationDate: Date?
    let willAutoRenew: Bool
    let nextProductID: String?
    let isFreeTrial: Bool
}
```

A plain value holding what the Account screen needs. It's filled from the subscription status in `refreshDetails()`.

- `productID`: the plan the user has **now**.
- `state`: Apple's renewal state: `.subscribed`, `.inGracePeriod`, `.inBillingRetryPeriod`, `.expired` or `.revoked`.
- `expirationDate`: when the current period ends. Optional (`Date?`) because StoreKit types it that way; for subscriptions it's always present.
- `willAutoRenew`: `false` means the user cancelled. They keep access until `expirationDate`.
- `nextProductID`: the plan they'll renew into. It differs from `productID` when a plan switch is scheduled.
- `isFreeTrial`: whether the current period is the free trial.
- All `let`: once built, a snapshot never changes; a new one is built on every refresh.

### `WinBackOffer`

```swift
struct WinBackOffer {
    let product: Product
    let offer: Product.SubscriptionOffer
}
```

- Pairs a win-back offer with the product it belongs to. The win-back screen needs both: the offer for its price, and the product for the regular price afterwards and for making the purchase.

### `PurchaseOutcome`

```swift
enum PurchaseOutcome {
    case success
    case cancelled
    case pending
}
```

- Our own simplified result, so views don't depend on StoreKit's more complex `Product.PurchaseResult`.
- Because it has no associated values, Swift makes it `Equatable` automatically, which is why views can write `== .success`.

### The class declaration

```swift
@MainActor
@Observable
final class SubscriptionStore {
```

- `@MainActor`: every property and method runs on the main thread. SwiftUI must be updated from the main thread, and this prevents two threads changing the store at once.
- `@Observable`: SwiftUI tracks which properties each view reads, and redraws that view when one of them changes.
- `final`: nothing can subclass it. It documents intent and lets the compiler optimise calls.
- `class`, not `struct`: one shared instance that every view sees, and that background tasks can update.

### State

```swift
    private(set) var products: [Product] = []
    private(set) var loadError: String?
    private(set) var activeProductID: String?
    private(set) var isEligibleForTrial = false
```

- `private(set)`: views can **read** these, but only the store can **change** them. All changes go through the store's own logic.
- `products`: the loaded `Product` values, sorted by price. Empty until loaded.
- `loadError`: a message if products failed to load; `nil` otherwise.
- `activeProductID`: the ID of the subscription the user is entitled to, or `nil` if none. **This single value decides access.**
- `isEligibleForTrial`: whether the paywall may advertise the free trial. Defaults to `false`, so the app never promises a trial it hasn't confirmed.

```swift
    private(set) var details: SubscriptionDetails?
    private(set) var hasLoadedEntitlements = false
    private(set) var winBackOffer: WinBackOffer?
```

- `details`: the Account screen's information, or `nil` when there's no current subscription.
- `hasLoadedEntitlements`: becomes `true` after the first entitlement check. Until then, the UI shows "checking" instead of wrongly showing locks.
- `winBackOffer`: the offer to show a lapsed subscriber, or `nil`.

### Derived values

```swift
    var isSubscribed: Bool {
        activeProductID != nil
    }
```

- A computed property: calculated each time it's read, never stored. Subscribed means "has an active product ID". Deriving it means it can never disagree with `activeProductID`.

```swift
    var subscriptionGroupID: String? {
        products.first?.subscription?.subscriptionGroupID
    }
```

- The ID of the "StreamLab Premium" group, read from any product in it. `?.` (optional chaining) returns `nil` if products haven't loaded. The Account screen passes it to Apple's Manage Subscription sheet.

```swift
    func planName(for productID: String) -> String {
        products.first { $0.id == productID }?.displayName ?? "Premium"
    }
```

- Finds the product with this ID and returns its display name ("Monthly"). If products failed to load, `?? "Premium"` gives a sensible fallback instead of nothing.

```swift
    func canWatch(isPremium: Bool) -> Bool {
        !isPremium || isSubscribed
    }
```

- **The single access rule.** Free titles are always watchable; premium titles need a subscription. Every screen calls this, so the rule can't drift between screens.

### Background task handles

```swift
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
```

- References to three long-running background tasks, kept so they stay alive and so `expiryTask` can be cancelled and replaced.
- `Task<Void, Never>`: a task that returns nothing and never throws.
- Optional (`?`) so they start as `nil`. This matters in `init`: Swift requires every stored property to have a value before `self` is used, and the optional's automatic `nil` provides it.
- `@ObservationIgnored`: these aren't UI state, so SwiftUI shouldn't track them.

### `init`: start listening

```swift
    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
```

- Runs when the store is created, at launch. Listening must start as early as possible, because StoreKit delivers updates that arrived while the app was closed as soon as someone listens.
- `Task { ... }`: starts background work.
- `[weak self]`: the task holds the store weakly, so it doesn't keep the store alive by itself. `self?` then means "if the store still exists".
- `for await result in Transaction.updates`: an async sequence that **never ends**. It waits for the next transaction pushed by StoreKit: renewals, refunds, Ask to Buy approvals, purchases on other devices, offer code redemptions, and unfinished transactions from earlier launches.
- `handle(result)`: verifies, refreshes and finishes each one (see below).

```swift
        statusTask = Task { [weak self] in
            
            for await _ in Product.SubscriptionInfo.Status.updates {
                await self?.refreshEntitlements()
            }
        }
    }
```

- A second listener for **status** changes. Some changes, such as a subscription expiring, create no new transaction, so `Transaction.updates` wouldn't report them.
- `for await _`: we don't use the status value itself (`_` discards it); any change is a reason to refresh everything.

### `loadProducts()`

```swift
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductID.all)
```

- `async`: callers must `await` it, because loading takes time.
- `Product.products(for:)`: StoreKit 2's call to fetch products by ID, from the `.storekit` file during development or the App Store in production. It throws if the request fails.
- It **silently drops unknown IDs**: a typo returns fewer products, not an error.

```swift
            products = loaded.sorted { $0.price < $1.price }
```

- StoreKit doesn't guarantee an order, so we sort by price: Monthly ($7.99) first, then Annual ($59.99).
- `$0` and `$1` are the two products being compared. `price` is a `Decimal`, which is exact for money.

```swift
            loadError = loaded.isEmpty ? "No products found. Check the scheme's StoreKit Configuration."
            : nil
```

- An empty result is treated as an error, because it's the symptom of the most common setup mistake (no StoreKit configuration selected, or wrong IDs). `? :` picks the message or `nil`.

```swift
        } catch {
            loadError = error.localizedDescription
        }
    }
```

- A thrown error (for example, network failure) becomes a readable message. `error` is provided automatically inside `catch`.

### `refreshEntitlements()`: the source of truth

```swift
    func refreshEntitlements() async {
        var active: String?
```

- A local variable to build the answer before publishing it.

```swift
        for await result in Transaction.currentEntitlements {
```

- `Transaction.currentEntitlements`: the transactions the user is entitled to **right now**. StoreKit has already removed expired and refunded subscriptions. It works offline and syncs across devices. Unlike `Transaction.updates`, this sequence ends once everything is listed.

```swift
            guard let transaction = try? checkVerified(result) else { continue }
```

- Each item is a `VerificationResult`. `checkVerified` returns the transaction if Apple's signature is valid, or throws if not.
- `try?` turns a throw into `nil`; `guard ... else { continue }` skips that item and moves to the next. Unverified data never grants access.

```swift
            if transaction.productType == .autoRenewable {
                active = transaction.productID
            }
        }
```

- Only auto-renewable subscriptions count, so a future one-off purchase can't be mistaken for Premium.

```swift
        activeProductID = active
```

- Publishes the answer **once**, after the loop. Setting it inside the loop could flash "not subscribed" mid-refresh.

```swift
        await refreshTrialEligibility()
        
        await refreshDetails()
        scheduleExpiryRefresh(at: details?.expirationDate)
        hasLoadedEntitlements = true
    }
```

- `refreshTrialEligibility()`: a purchase or refund changes eligibility, so it's rechecked every time.
- `refreshDetails()`: rebuilds the Account screen's details and the win-back offer.
- `scheduleExpiryRefresh(...)`: sets a timer for the moment the current period ends, so expiry is noticed even if no event arrives.
- `hasLoadedEntitlements = true`: set **last**, so the UI only stops showing "checking" once everything is up to date.

### `refreshTrialEligibility()`

```swift
    func refreshTrialEligibility() async {
        guard let subscription = products.first?.subscription else { return }
        isEligibleForTrial = await subscription.isEligibleForIntroOffer
    }
```

- Needs any product in the group; without products it leaves the value unchanged (`false` at launch).
- `isEligibleForIntroOffer`: asks StoreKit whether this customer has never had an intro offer in this group. It's `async` because StoreKit checks purchase history. Eligibility is **per group**, so checking one product covers both.

### `refreshDetails()`

```swift
    func refreshDetails() async {
        guard let subscription = products.first?.subscription,
              let statuses = try? await subscription.status else {
            details = nil
            winBackOffer = nil
            return
        }
```

- `subscription.status`: the full status of the group, as an array of `Status` values. It's an array because Family Sharing can give a user more than one.
- If products aren't loaded or the call fails, clear both values and stop.

```swift
        winBackOffer = findWinBackOffer(in: statuses)
```

- Uses the same statuses to look for a win-back offer (explained below).

```swift
        let activeStates: [Product.SubscriptionInfo.RenewalState] = [.subscribed, .inGracePeriod, .inBillingRetryPeriod]
```

- The states where the Account screen should show subscription details. Billing retry is included even though the user has no access then, so the screen can show the payment warning and Manage button.

```swift
        guard let status = statuses.first(where: { activeStates.contains($0.state) }),
              let transaction = try? checkVerified(status.transaction),
              let renewalInfo = try? checkVerified(status.renewalInfo) else {
            details = nil
            return
        }
```

- Picks the first status in an active state.
- Verifies both signed parts: `transaction` (the latest transaction) and `renewalInfo` (what happens next). The generic `checkVerified` handles both types.
- If any step fails, there are no details to show.

```swift
        details = SubscriptionDetails(
            productID: transaction.productID,
            state: status.state,
            expirationDate: transaction.expirationDate,
            willAutoRenew: renewalInfo.willAutoRenew,
            nextProductID: renewalInfo.autoRenewPreference,
            isFreeTrial: transaction.offer?.paymentMode == .freeTrial
        )
    }
```

- Builds the snapshot:
  - `autoRenewPreference`: the product the user will renew into.
  - `transaction.offer?.paymentMode == .freeTrial`: `offer` (iOS 17.2+) describes any offer applied to this transaction. A free-trial payment mode means the current period is the trial.

### `scheduleExpiryRefresh(at:)`

```swift
    private func scheduleExpiryRefresh(at date: Date?) {
        expiryTask?.cancel()
        guard let date, date > .now else { return }
```

- `expiryTask?.cancel()`: throws away the previous timer, so only one is ever waiting.
- `guard let date, date > .now`: no date, or a date in the past, means nothing to schedule. `guard let date` is shorthand for `guard let date = date`.

```swift
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(date.timeIntervalSinceNow + 1))
            guard !Task.isCancelled else { return }
            await self?.refreshEntitlements()
        }
    }
```

- `Task.sleep(for:)`: waits without blocking anything, until one second after expiry. The extra second gives StoreKit time to record the expiry.
- `try?`: `sleep` throws if the task is cancelled; we ignore that error.
- `guard !Task.isCancelled`: if this timer was replaced while sleeping, don't refresh.
- It also helps active subscribers: after a renewal, the refresh picks up the new period and schedules the next timer.

### `findWinBackOffer(in:)`

```swift
    private func findWinBackOffer(in statuses: [Product.SubscriptionInfo.Status]) -> WinBackOffer? {
        let activeStates: [Product.SubscriptionInfo.RenewalState] = [.subscribed, .inGracePeriod, .inBillingRetryPeriod]
        guard !statuses.contains(where: { activeStates.contains($0.state) }) else { return nil }
```

- Win-back offers are for **lapsed** customers only. If any status is active, return `nil` immediately.

```swift
        for status in statuses where status.state == .expired {
            guard let renewalInfo = try? checkVerified(status.renewalInfo) else { continue }
```

- Looks only at expired statuses (`where` filters the loop). A refunded subscription is `.revoked`, not a lapsed customer.
- Verifies the renewal info; skips it if invalid.

```swift
            for offerID in renewalInfo.eligibleWinBackOfferIDs {
                for product in products {
                    if let offer = product.subscription?.winBackOffers.first(where: { $0.id == offerID }) {
                        return WinBackOffer(product: product, offer: offer)
                    }
                }
            }
        }
        
        return nil
    }
```

- `eligibleWinBackOfferIDs` (iOS 18): IDs of offers **Apple** says this customer can redeem now. Apple decides eligibility from rules set in App Store Connect; in Xcode, from the offer's Eligible setting.
- The inner loops find the actual offer object with that ID among the products' configured `winBackOffers`. We need the object for its price and period.
- Returns the first match, or `nil` if there is none.

### `restore()`

```swift
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }
```

- `AppStore.sync()`: forces StoreKit to fetch the latest transactions from Apple. It can prompt the user to sign in, so it's only called when the user taps Restore Purchases.
- Then refreshes entitlements so the UI reflects anything restored.
- `throws`: a failed sync is passed back to the screen to show an error.

### `purchase(_:winBackOffer:)`

```swift
    func purchase(_ product: Product, winBackOffer offer: Product.SubscriptionOffer? = nil) async throws -> PurchaseOutcome {
```

- `_ product`: no argument label, so callers write `purchase(monthly)`.
- `winBackOffer offer`: the external label is `winBackOffer`; inside, it's called `offer`.
- `= nil`: optional, so normal purchases don't mention it.

```swift
        var options: Set<Product.PurchaseOption> = []
        if let offer {
            options.insert(.winBackOffer(offer))
        }
```

- Purchase options are passed as a set. When an offer is given, add `.winBackOffer(offer)`, which tells StoreKit to apply that discount.

```swift
        let result = try await product.purchase(options: options)
        return try await process(result)
    }
```

- `product.purchase(options:)`: shows Apple's payment sheet and waits for the result. **The options must be passed here**; without them the offer is silently ignored and the full price is charged.
- `process(result)`: the shared handling, also used by the StoreKit paywall.

### `process(_:)`

```swift
    func process(_ result: Product.PurchaseResult) async throws -> PurchaseOutcome {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshEntitlements()
            await transaction.finish()
            return .success
```

- `.success` carries a `VerificationResult`, not a transaction. `checkVerified` unwraps it, or throws if the signature is invalid.
- **Order matters:** first deliver (refresh entitlements so content unlocks), then `finish()`. `finish()` tells the App Store the purchase was delivered; without it, StoreKit re-sends the transaction through `Transaction.updates` on every launch.

```swift
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }
```

- `.userCancelled`: the user closed the sheet. Not an error.
- `.pending`: waiting for approval (Ask to Buy, bank checks). The final result arrives later through `Transaction.updates`.
- `@unknown default`: covers cases Apple may add in future iOS versions, so the code keeps compiling and behaves safely.

### `handle(_:)`

```swift
    private func handle(_ result:VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        
        print("Transaction update:", transaction.productID, "revoked:", transaction.revocationDate != nil)
        
        await refreshEntitlements()
        await transaction.finish()
    }
```

- Called for each item from `Transaction.updates`.
- Ignores unverified transactions.
- `print(...)`: debug output in Xcode's console. `revocationDate` is set when Apple refunds or revokes a purchase. **Note:** debug-only; see the review notes.
- Doesn't inspect what kind of update it was: it simply re-asks `currentEntitlements`, which already reflects renewals and refunds. One code path covers every case.
- Then finishes the transaction.

### `checkVerified(_:)`

```swift
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
```

- `<T>` makes it **generic**: it works for `VerificationResult<Transaction>` and `VerificationResult<RenewalInfo>` alike.
- StoreKit checks Apple's cryptographic signature on the device. `.verified` gives the value; `.unverified` (possible on a tampered device) throws its error. `_` ignores the unverified value itself.

---

## 5. Store/Product+Paywall.swift

Helpers that turn StoreKit's periods into readable text.

```swift
import StoreKit

extension Product {
    var pricePerPeriod: String {
        guard let period = subscription?.subscriptionPeriod else { return displayPrice }
        return "\(displayPrice)/\(period.recurringText)"
    }
}
```

- `extension Product`: adds a property to Apple's `Product` type without subclassing it.
- `pricePerPeriod`: "$7.99/month" or "$59.99/year".
- For a non-subscription product there's no period, so it falls back to just the price.
- `displayPrice` is StoreKit's localised price string, in the customer's currency.

```swift
extension Product.SubscriptionPeriod {
    var unitName: String {
        switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
    }
```

- A `SubscriptionPeriod` has a `unit` and a `value` (for example, 1 month). This maps the unit to a word.
- Each `case` returns a value directly (`switch` as an expression, Swift 5.9+).
- `@unknown default`: future units fall back to "period".

```swift
    var recurringText: String {
        value == 1 ? unitName : "\(value) \(unitName)s"
    }
```

- "month" for 1, "3 months" for 3. Used after the "/" in prices.

```swift
    var trialText: String {
        switch unit {
        case .day: "\(value)-day"
        case .week: "\(value * 7)-day"
        default: "\(value)-\(unitName)"
        }
    }
}
```

- Text for trial lengths: "7-day". A week is converted to days because "7-day free trial" is the common wording, and StoreKit may report a week as either `.week` or 7 `.day`s; both now read "7-day".

---

## 6. Shared/AppLinks.swift

```swift
import Foundation

enum AppLinks {
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicy = URL(string: "https://github.com/Akshayiyerg/StreamLab/blob/main/PRIVACY.md")!
}
```

- `Foundation`: provides `URL`.
- A namespace enum (like `ProductID`) for the two legal links that every subscribe screen must show (Guideline 3.1.2).
- `termsOfUse`: Apple's standard EULA.
- `privacyPolicy`: the `PRIVACY.md` file in your repo.
- `URL(string:)` returns an optional; `!` force-unwraps it. That's safe here only because these are fixed, known-valid strings. One definition means no screen can go out of date.

---

## 7. Catalog/Video.swift

The shape of one video in the JSON from the server.

```swift
import Foundation

struct Video: Codable, Identifiable, Hashable {
```

- `Codable`: can be decoded from JSON automatically, because the property names match the JSON keys.
- `Identifiable`: has an `id`, which SwiftUI lists use.
- `Hashable`: can be used in sets and as a navigation value. **Note:** no longer needed, since navigation uses `CachedVideo`; it's harmless.

```swift
    let id: String
    let title: String
    let synopsis: String
    let category: String
    let durationMinutes: Int
    let isPremium: Bool
    let streamURL: URL
}
```

- One property per JSON key. `let` because a downloaded video doesn't change.
- `streamURL: URL`: the decoder converts the JSON string into a `URL`; an invalid URL would make decoding fail.
- `isPremium`: decides whether the title needs a subscription.

---

## 8. Catalog/CachedVideo.swift

The shape of one video saved on the device by SwiftData.

```swift
import Foundation
import SwiftData

@Model
final class CachedVideo {
```

- `@Model`: SwiftData's macro. It generates the code to save this class to the database and track changes to its properties.
- It must be a `class`, because SwiftData tracks each object's identity and changes over time.

```swift
    @Attribute(.unique) var id: String
```

- `@Attribute(.unique)`: no two records can share an `id`. Inserting a duplicate updates the existing record instead.

```swift
    var title: String
    var synopsis: String
    var category: String
    var durationMinutes: Int
    var isPremium: Bool
    var streamURL: URL
    var sortIndex: Int
```

- The same fields as `Video`, as `var` so they can be updated when the server changes.
- `sortIndex`: the video's position in the server's list. A database has no natural order, so we store it and sort by it.

```swift
    init(video: Video, sortIndex: Int) {
        self.id = video.id
        self.title = video.title
        self.synopsis = video.synopsis
        self.category = video.category
        self.durationMinutes = video.durationMinutes
        self.isPremium = video.isPremium
        self.streamURL = video.streamURL
        self.sortIndex = sortIndex
    }
```

- Creates a new record from a downloaded `Video`. `self.` distinguishes the property from the parameter where names match.

```swift
    func update(from video: Video, sortIndex: Int) {
        title = video.title
        synopsis = video.synopsis
        category = video.category
        durationMinutes = video.durationMinutes
        isPremium = video.isPremium
        streamURL = video.streamURL
        self.sortIndex = sortIndex
    }
}
```

- Updates an existing record with fresh data. `id` isn't updated, because it's how the record is matched. `self.sortIndex` needs `self.` because the parameter has the same name.

---

## 9. Catalog/CatalogService.swift

Downloads the catalogue from GitHub.

```swift
import Foundation

enum CatalogError: LocalizedError {
    case badResponse(Int)
```

- Our own error type. `badResponse` carries the HTTP status code.
- `LocalizedError`: lets us provide a readable `errorDescription`.

```swift
    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            return "The server returned an error (\(code))."
        }
    }
}
```

- The text shown by `error.localizedDescription`, for example "The server returned an error (404)."

```swift
struct CatalogService {
    static let url = URL(string: "https://raw.githubusercontent.com/Akshayiyerg/StreamLab/main/catalog.json")!
```

- The raw file URL of `catalog.json` in your repo. GitHub serves it like a simple API. `static` because it's the same for every instance.

```swift
    func fetchCatalog() async throws -> [Video] {
        var request = URLRequest(url: Self.url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
```

- `async throws`: takes time and can fail.
- `URLRequest`: lets us set options on the request. `Self.url` refers to the static property.
- `.reloadIgnoringLocalCacheData`: turns off `URLSession`'s own HTTP cache. Otherwise, offline behaviour could come from that hidden cache; we want offline to come only from our SwiftData cache.

```swift
        let (data, response) = try await URLSession.shared.data(for: request)
```

- Performs the HTTP request. Returns the body (`data`) and metadata (`response`). Throws only if the request can't complete, such as with no network.

```swift
        guard let http = response as? HTTPURLResponse else {
            throw CatalogError.badResponse(0)
        }
        guard http.statusCode == 200 else {
            throw CatalogError.badResponse(http.statusCode)
        }
```

- `as?` casts to `HTTPURLResponse` to read the status code; `0` if it isn't an HTTP response.
- `URLSession` treats a 404 or 500 as success, so we check the status ourselves. Without this, an error page would reach the JSON decoder and fail with a confusing message.

```swift
        return try JSONDecoder().decode([Video].self, from: data)
    }
}
```

- Decodes the body as an array of `Video`. Throws if the JSON doesn't match.

---

## 10. Catalog/CatalogRepository.swift

Combines the network and the database: fetch, then save into SwiftData.

```swift
import Foundation
import SwiftData

@MainActor
struct CatalogRepository {
    private let service = CatalogService()
```

- `@MainActor`: runs on the main thread, the same thread as the view's `ModelContext`. A `ModelContext` must only be used on the thread it belongs to.
- `service`: the network layer, owned privately.

```swift
    func refresh(into context: ModelContext) async throws {
        let videos = try await service.fetchCatalog()
```

- Takes the context to save into, from the view.
- Fetches first. If that throws (for example, offline), the function stops here and the saved data is left untouched; that's what makes offline mode work.

```swift
        let existing = try context.fetch(FetchDescriptor<CachedVideo>())
        var cachedByID = Dictionary(uniqueKeysWithValues: existing.map { ( $0.id, $0 ) })
```

- `FetchDescriptor<CachedVideo>()`: "all `CachedVideo` records". `context.fetch` runs it.
- Builds a dictionary from `id` to record for fast lookup. `uniqueKeysWithValues` would crash on duplicate IDs, which `@Attribute(.unique)` prevents.

```swift
        for (index, video) in videos.enumerated() {
            if let cached = cachedByID.removeValue(forKey: video.id) {
                cached.update(from: video, sortIndex: index)
            } else {
                context.insert(CachedVideo(video: video, sortIndex: index))
            }
        }
```

- `enumerated()` gives each video with its position, used as `sortIndex`.
- `removeValue(forKey:)` returns the existing record **and** removes it from the dictionary in one step.
  - Found: update it in place (keeps the same object, so the list doesn't flash).
  - Not found: insert a new record.
- This is an **upsert**: update existing, insert new.

```swift
        for stale in cachedByID.values {
            context.delete(stale)
        }
```

- Anything left in the dictionary wasn't in the server's response, so it's deleted.

```swift
        try context.save()
    }
}
```

- Writes all changes to disk. `@Query` in `HomeView` then re-runs automatically, and the list updates.

---

## 11. Features/Home/HomeView.swift

The catalogue list, with offline support and locks.

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedVideo.sortIndex) private var videos: [CachedVideo]
```

- `@Environment(SubscriptionStore.self)`: reads the shared store.
- `@Environment(\.modelContext)`: the SwiftData context created by `.modelContainer` in the app.
- `@Query(sort:)`: fetches all `CachedVideo` records sorted by `sortIndex`, and **redraws the view whenever they change**. The list reads only from the database.

```swift
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let repository = CatalogRepository()
```

- `isLoading`: true while a fetch is running, for the spinner.
- `errorMessage`: the last fetch error, or `nil`. Drives both the full-screen error and the offline banner.
- `repository`: does the fetching and saving.

```swift
    var body: some View {
        NavigationStack {
            List(videos) { video in
                NavigationLink(value: video) {
```

- `NavigationStack`: enables pushing the detail screen.
- `List(videos)`: one row per video. Works because `CachedVideo` is `Identifiable` (every `@Model` is).
- `NavigationLink(value: video)`: tapping the row pushes a screen for this video; which screen is decided by `.navigationDestination` below.

```swift
                    HStack(spacing: 12) {
                        PosterView(category: video.category)
                            .frame(width: 64, height: 40)
                            .clipShape(.rect(cornerRadius: 6))
```

- `HStack`: arranges the row horizontally.
- A small poster thumbnail, clipped to rounded corners.

```swift
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(.headline)
                            Text("\(video.category) · \(video.durationMinutes) min")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
```

- Title, then category and duration in a smaller grey font. `alignment: .leading` left-aligns the text.

```swift
                        Spacer()
                        
                        if store.hasLoadedEntitlements && !store.canWatch(isPremium: video.isPremium) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
            }
```

- `Spacer()` pushes the lock to the right edge.
- The lock shows only when entitlements have loaded **and** the user can't watch. The first condition prevents locks flashing for subscribers at launch.

```swift
            .navigationDestination(for: CachedVideo.self) { video in
                VideoDetailView(video: video)
                
            }
```

- Says which screen to build when a `CachedVideo` is pushed. Works because every `@Model` is `Hashable`.

```swift
            .overlay {
                if isLoading && videos.isEmpty {
                    ProgressView()
                } else if let errorMessage, videos.isEmpty {
```

- `.overlay`: content drawn on top of the list.
- Spinner only on a first load with nothing saved.
- `if let errorMessage`: shorthand unwrap. Shows the error only when there's nothing saved to show instead.

```swift
                    ContentUnavailableView {
                        Label("Can't load catalogue", systemImage: "wifi.slash")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") {
                            Task { await load() }
                        }
                    }
                }
            }
```

- `ContentUnavailableView`: Apple's standard empty-state view, with a title, description and actions.
- `Task { await load() }`: a button action is synchronous, so the async `load()` runs inside a `Task`.

```swift
            .safeAreaInset(edge: .top) {
                if errorMessage != nil && !videos.isEmpty {
                    Label("Offline · showing saved catalogue", systemImage: "wifi.slash")
                        .font(.footnote)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(.yellow.opacity(0.3))
                }
            }
```

- `.safeAreaInset(edge: .top)`: places the banner at the top and pushes the list down instead of covering it.
- Shown only when the fetch failed **and** saved data exists.
- `frame(maxWidth: .infinity)` makes it full width; the light yellow background makes it noticeable.

```swift
            .navigationTitle("StreamLab")
            .refreshable {
                await load()
            }
            .task {
                await load()
            }
        }
    }
```

- `.navigationTitle`: the large title.
- `.refreshable`: pull to refresh.
- `.task`: loads when the screen first appears. Saved data shows immediately through `@Query` while this runs: cache-then-network.

```swift
    private func load() async {
        isLoading = true
        
        defer { isLoading = false}
             
        do {
            try await repository.refresh(into: modelContext)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- `defer`: runs when the function exits, by success or error, so the spinner can't get stuck.
- On success, clears any previous error (which also hides the banner). The list updates by itself through `@Query`.
- On failure, stores the message. The saved data stays on screen.

---

## 12. Features/Home/PosterView.swift

A drawn poster, since there are no poster images.

```swift
import SwiftUI

struct PosterView: View {
    let category: String
```

- The category decides the colours and symbol.

```swift
    private var style: (colors: [Color], symbol: String) {
        switch category {
        case "Animation": ([.orange, .pink], "sparkles")
        case "Sci-Fi": ([.indigo, .purple], "atom")
        case "Tech Demos": ([.teal, .blue], "waveform")
        default: ([.gray, .black], "film")
        }
    }
```

- Returns a **tuple** with named parts, `colors` and `symbol`, so `body` can write `style.colors`.
- Each case returns a value directly. `default` covers categories added to the JSON later.

```swift
    var body: some View {
        LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: style.symbol)
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.85))
            }
    }
}
```

- A diagonal gradient from top-left to bottom-right, with the SF Symbol centred on top in slightly transparent white.
- The size is set by whoever uses it, via `.frame`.

---

## 13. Features/Home/VideoDetailView.swift

The detail screen: Play for allowed titles, the paywall otherwise.

```swift
import SwiftUI

struct VideoDetailView: View {
    let video: CachedVideo
    
    @Environment(SubscriptionStore.self) private var store
    @State private var showPlayer = false
    @State private var showPlans = false
```

- `video`: passed in from Home's navigation.
- `showPlayer` and `showPlans`: control the full-screen player and the paywall sheet.

```swift
    private var canWatch: Bool {
        store.canWatch(isPremium: video.isPremium)
    }
```

- Shorthand for the shared access rule, used several times in `body`.

```swift
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PosterView(category: video.category)
                    .frame(height: 220)
                    .clipShape(.rect(cornerRadius: 16))
```

- `ScrollView` so a long synopsis can scroll.
- A large poster, full width and 220 points tall.

```swift
                Text(video.title)
                    .font(.largeTitle.bold())
                
                Text("\(video.category) · \(video.durationMinutes) min\(video.isPremium ? " · Premium" : "")")
                    .foregroundStyle(.secondary)
```

- The title, then a details line. The `? :` inside the string adds " · Premium" only for premium titles.

```swift
                Button {
                    if canWatch {
                        showPlayer = true
                    } else {
                        showPlans = true
                    }
                } label: {
                    Label(canWatch ? "Play" : "Unlock with Premium", systemImage: canWatch ? "play.fill" : "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
```

- One button with two behaviours: play, or open the paywall.
- The label and icon also switch.
- `frame(maxWidth: .infinity)` makes it full width; `.borderedProminent` and `.large` make it the main action.

```swift
                Text(video.synopsis)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
```

- The synopsis, then padding around the content.
- `.inline`: a small navigation bar, since the big title is already in the content.

```swift
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(url: video.streamURL, isPremium: video.isPremium)
        }
        .sheet(isPresented: $showPlans) {
            PaywallSheet()
        }
```

- `.fullScreenCover`: the player takes the whole screen. `$showPlayer` is a **binding**, letting the cover set it back to `false` when dismissed.
- `.sheet`: the paywall slides up and can be swiped away. `PaywallSheet` chooses which paywall to show.

```swift
        .onChange(of: store.isSubscribed) {
            if store.isSubscribed {
                showPlans = false
            }
        }
    }
}
```

- When a purchase succeeds, closes the paywall, so the user lands straight on a Play button.

---

## 14. Features/Player/PlayerView.swift

Video playback, closing itself if access is lost.

```swift
import SwiftUI
import AVKit

struct PlayerView: View {
    let url: URL
    let isPremium: Bool
```

- `AVKit`: provides SwiftUI's `VideoPlayer` and `AVPlayer`.
- `isPremium` is passed in so the player can re-check access by itself.

```swift
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
```

- `dismiss`: closes this full-screen cover.
- `player`: held in `@State` so it's created once and survives redraws. Creating `AVPlayer` inside `body` would restart the video on every redraw.

```swift
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
                
                Spacer()
            }
            .padding(.horizontal)
```

- `VStack` puts our close bar **above** the video, not over it, so it can't collide with the player's own AirPlay and mute buttons.
- 44 × 44 points is Apple's minimum touch target size.
- `.accessibilityLabel("Close")`: VoiceOver says "Close" instead of "xmark".
- `Spacer()` pushes the button to the left.

```swift
            if let player {
                VideoPlayer(player: player)
            } else {
                Spacer()
            }
        }
        .background(Color.black.ignoresSafeArea())
```

- Shows the player once it exists; before that, a `Spacer` keeps the bar at the top.
- A black background that extends under the status bar and home indicator.

```swift
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
```

- `AVAudioSession` category `.playback`: sound plays even with the silent switch on, like other video apps.
- Creates the player for the HLS stream URL, stores it, and starts playback.

```swift
        .onDisappear {
            player?.pause()
        }
```

- Stops playback when the player closes, so audio doesn't continue in the background.

```swift
        .onChange(of: store.isSubscribed) {
            if !store.canWatch(isPremium: isPremium) {
                player?.pause()
                dismiss()
            }
        }
    }
}
```

- **Gate at every door:** if a refund or expiry removes access mid-playback, stop and close. Free titles are unaffected, because `canWatch` is always `true` for them.

---

## 15. Features/Paywall/PaywallStyle.swift

The paywall style setting, and the view that picks which paywall to show.

```swift
import SwiftUI

enum PaywallStyle: String, CaseIterable, Identifiable {
    case custom
    case storeKit
```

- `String` raw values ("custom", "storeKit"), so `@AppStorage` can save it as text.
- `CaseIterable`: gives `PaywallStyle.allCases` for the picker.
- `Identifiable`: lets `ForEach` loop over the cases.

```swift
    static let storageKey = "paywallStyle"
    
    var id: Self { self }
```

- `storageKey`: the `UserDefaults` key, defined once so both readers use the same one.
- `id`: each case identifies itself, which satisfies `Identifiable`.

```swift
    var title: String {
        switch self {
        case .custom: "Custom"
        case .storeKit: "StoreKit view"
        }
    }
}
```

- The text shown in the picker.

```swift
struct PaywallSheet: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage(PaywallStyle.storageKey) private var style = PaywallStyle.custom
    @State private var showAllPlans = false
```

- `@AppStorage`: reads the saved style from `UserDefaults` and redraws when it changes. Defaults to custom.
- `showAllPlans`: becomes true when the user taps "See all plans" on the win-back screen.

```swift
    var body: some View {
        switch style {
        case .custom:
            if let winBack = store.winBackOffer, !showAllPlans {
                WinBackOfferView(winBack: winBack) {
                    showAllPlans = true
                }
            } else {
                PaywallView()
            }
        case .storeKit:
            StoreKitPaywallView()
        }
    }
}
```

- Custom style: a lapsed customer with an offer sees the win-back screen first. The trailing closure is `onShowAllPlans`, which switches to the regular paywall.
- StoreKit style: Apple's view, which shows eligible win-back offers by itself.

---

## 16. Features/Paywall/PaywallView.swift

The custom paywall.

```swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
```

- `StoreKit` for the `Product` type. `dismiss` closes the sheet.

```swift
    @State private var selectedID = ProductID.annual
    @State private var isPurchasing = false
    @State private var alertTitle = ""
    @State private var alertMessage: String?
```

- `selectedID`: the chosen plan, Annual by default.
- `isPurchasing`: shows a spinner and disables the button during a purchase.
- `alertTitle` and `alertMessage`: the alert's content. A non-`nil` message means "show the alert".

```swift
    private var monthly: Product? { store.products.first { $0.id == ProductID.monthly } }
    private var annual: Product? { store.products.first { $0.id == ProductID.annual } }
    private var selected: Product? { store.products.first { $0.id == selectedID } }
```

- Look up products by ID. Optional, because products may not have loaded.

```swift
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    plans
                    subscribeButton
                    finePrint
                }
                .padding()
            }
```

- `NavigationStack` gives the sheet a toolbar for the Close button.
- `body` stays short by calling four computed properties, each one section of the screen.

```swift
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
```

- `.cancellationAction`: the standard spot for a close or cancel button. A paywall must always be dismissible.

```swift
            .alert(alertTitle, isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }
```

- `.alert` needs a true/false binding. This custom `Binding` reports `true` while there's a message, and clears the message when the alert is dismissed (`set` receives `false`).
- `role: .cancel`: the standard dismiss style.

### Sections

```swift
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            
            Text("StreamLab Premium")
                .font(.largeTitle.bold())
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Every title in the catalogue", systemImage: "film.stack")
                Label("Watch on iPhone and iPad", systemImage: "ipad.and.iphone")
                Label("Cancel anytime", systemImage: "checkmark.circle")
            }
        }
    }
```

- An icon in the app's accent colour (`.tint`), the title, and three benefits. Every benefit must be true (Guideline 3.1 accuracy).

```swift
    private var plans: some View {
        VStack(spacing: 12) {
            if store.products.isEmpty {
                ContentUnavailableView {
                    Label("Plans unavailable", systemImage: "exclamationmark.icloud")
                } description: {
                    Text("We couldn't load the subscription options. Check your connection and try again.")
                } actions: {
                    Button("Try Again") {
                        Task {
                            await store.loadProducts()
                            await store.refreshEntitlements()
                        }
                    }
                }
            }
```

- If products didn't load, show a retry state instead of a blank, broken-looking paywall.
- "Try Again" reloads products, then entitlements, because trial eligibility depends on products.

```swift
            if let annual {
                PlanCard(
                    product: annual,
                    isSelected: selectedID == annual.id,
                    badge: savingsBadge,
                    detail: "\((annual.price / 12).formatted(annual.priceFormatStyle))/month, billed yearly"
                ) {
                    selectedID = annual.id
                }
            }
```

- The Annual card with the "Save 37%" badge.
- The detail divides the yearly `Decimal` price by 12 and formats it in the customer's currency with `priceFormatStyle`. It's secondary text; the billed amount ($59.99/year) stays the most prominent.
- The trailing closure is the card's tap action, which selects Annual.

```swift
            if let monthly {
                PlanCard(
                    product: monthly,
                    isSelected: selectedID == monthly.id,
                    badge: nil,
                    detail: trialText(for: monthly)
                ) {
                    selectedID = monthly.id
                }
            }
        }
    }
```

- The Monthly card. Its detail is "7-day free trial" only when the user is eligible; otherwise `nil` (nothing shown).

```swift
    private var subscribeButton: some View {
        Button {
            Task { await buy() }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                } else {
                    Text(buttonTitle)
                        .bold()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selected == nil || isPurchasing)
    }
```

- Starts the purchase in a `Task`.
- `Group` lets the label switch between a spinner and text, while one `.frame` applies to both.
- Disabled when no product is selected, or while purchasing, to prevent double taps.

```swift
    private var finePrint: some View {
        VStack(spacing: 12) {
            Text(termsText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Restore Purchases") {
                    Task { await restore() }
                }
                Link("Terms of Use", destination: AppLinks.termsOfUse)
                Link("Privacy Policy", destination: AppLinks.privacyPolicy)
            }
            .font(.footnote)
        }
    }
```

- The required disclosures (trial terms, auto-renewal, cancellation), then Restore and the two legal links.
- `Link` opens a URL in Safari.

### Text helpers

```swift
    private var savingsBadge: String? {
        guard let monthly, let annual else { return nil }
        let yearlyAtMonthlyPrice = monthly.price * 12
        guard yearlyAtMonthlyPrice > 0 else { return nil }
```

- Needs both products. The cost of a year paid monthly: $95.88.
- The `> 0` check avoids dividing by zero.

```swift
        let saving = (1 - annual.price / yearlyAtMonthlyPrice ) * 100
        let percent = Int(NSDecimalNumber(decimal: saving).doubleValue.rounded())
        return percent > 0 ? "Save \(percent)%" : nil
    }
```

- `1 - 59.99 / 95.88 = 0.374`, times 100 is 37.4.
- `Decimal` keeps money exact; it's converted to `Double` only to round, via `NSDecimalNumber`.
- No badge if there's no saving.

```swift
    private func trialText(for product: Product) -> String? {
        guard store.isEligibleForTrial,
              let intro = product.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }
        return "\(intro.period.trialText) free trial"
    }
```

- Returns "7-day free trial" only when all three hold: the user is eligible, the product has an intro offer, and that offer is free. Otherwise `nil`, so no trial wording appears anywhere.

```swift
    private var buttonTitle: String {
        guard let selected else { return "Subscribe" }
        if let trial = trialText(for: selected) {
            return "Start \(trial)"
        }
        return "Subscribe for \(selected.pricePerPeriod)"
    }
```

- "Start 7-day free trial" when a trial applies, otherwise "Subscribe for $59.99/year".

```swift
    private var termsText: String {
        guard let selected else { return "" }
        var text = ""
        if let trial = trialText(for: selected) {
            text += "After your \(trial), you'll be charged \(selected.pricePerPeriod). "
        }
        text += "Payment is charged to your Apple Account. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel it anytime in your Apple Account settings."
        return text
    }
```

- Builds the disclosure: what happens after the trial (only when there is one), then payment, auto-renewal and cancellation. These are the Guideline 3.1.2 requirements.

### Actions

```swift
    private func buy() async {
        guard let selected else { return }
        isPurchasing = true
        defer { isPurchasing = false }
```

- Sets the spinner, and `defer` guarantees it's cleared however the function ends.

```swift
        do {
            switch try await store.purchase(selected) {
            case .success:
                dismiss()
            case .pending:
                showAlert("Waiting for approval", "You'll get access as soon as the purchase is approved.")
            case .cancelled:
                break
            }
        } catch {
            showAlert("Purchase failed", error.localizedDescription)
        }
    }
```

- Success closes the paywall.
- Pending explains the wait.
- Cancelled does nothing, because closing the sheet isn't an error.
- A thrown error shows "Purchase failed".

```swift
    private func restore() async {
        do {
            try await store.restore()
            if store.isSubscribed {
                dismiss()
            } else {
                showAlert("Nothing to restore", "No active subscription was found for this Apple Account.")
            }
        } catch {
            showAlert("Restore failed", error.localizedDescription)
        }
    }
```

- After syncing, either close (subscription found) or explain that nothing was found.

```swift
    private func showAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
    }
}
```

- Sets both values. Setting the message triggers the alert through the custom binding.

### `PlanCard`

```swift
private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let detail: String?
    let action: () -> Void
```

- `private`: only usable in this file.
- `action`: a closure run when the card is tapped.

```swift
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.green, in: .capsule)
                                .foregroundStyle(.white)
                        }
                    }
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
```

- The whole card is a `Button`.
- Left side: the plan name and optional green capsule badge, then the optional detail line.

```swift
                Spacer()
                
                Text(product.pricePerPeriod)
                    .font(.headline)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
```

- Right side: the billed price, prominent, and a selection circle that fills when selected.

```swift
            .padding()
            .background(.background.secondary, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

- A rounded grey card background that adapts to dark mode.
- An accent-coloured border only when selected.
- `.contentShape(.rect)`: the whole rectangle is tappable, including empty space.
- `.buttonStyle(.plain)`: stops the default blue tint on the text.
- `.accessibilityAddTraits(.isSelected)`: VoiceOver announces the selected plan.

---

## 17. Features/Paywall/StoreKitPaywallView.swift

Apple's ready-made paywall.

```swift
import SwiftUI
import StoreKit

struct StoreKitPaywallView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var errorMessage: String?
```

- `store`: for the shared `process` function.
- `errorMessage`: drives the failure alert.

```swift
    var body: some View {
        SubscriptionStoreView(productIDs: ProductID.all) {
            VStack(spacing: 12) {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("StreamLab Premium")
                    .font(.largeTitle.bold())
                Text("Every title in the catalogue. Cancel anytime.")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding()
        }
```

- `SubscriptionStoreView(productIDs:)`: Apple's paywall (iOS 17+). It loads the products, shows prices, checks trial and win-back eligibility, and runs the purchase.
- The closure is our marketing header above the plans.

```swift
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
```

- `.prominentPicker`: plans as large selectable cards.
- `.multiline`: the purchase button shows two lines (action and price terms).

```swift
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .storeButton(.visible, for: .policies)
```

- Turns on Apple's built-in Restore button, the close button, and the policy links.

```swift
        .subscriptionStorePolicyDestination(url: AppLinks.termsOfUse,
        for: .termsOfService
        )
        .subscriptionStorePolicyDestination(url: AppLinks.privacyPolicy, for: .privacyPolicy
        )
```

- Points those policy links at our URLs. **Note:** the line breaks are unusual; see the review notes.

```swift
        .onInAppPurchaseCompletion { _, result in
            switch result {
            case .success(let purchaseResult):
                do {
                    if try await store.process(purchaseResult) == .success {
                        dismiss()
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
```

- Called after Apple's view finishes a purchase. `_` ignores the product parameter.
- The outer `Result`: whether the purchase could run at all. `.failure` shows an alert.
- `.success` carries the familiar `PurchaseResult`, which goes into the **same** `process` function as the custom paywall: verify, refresh, finish. Close on success.

```swift
        .alert("Purchase failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
```

- The same message-driven alert pattern as the custom paywall.

---

## 18. Features/Paywall/WinBackOfferView.swift

The "Welcome back" offer for lapsed subscribers.

```swift
import SwiftUI
import StoreKit

struct WinBackOfferView: View {
    let winBack: WinBackOffer
    let onShowAllPlans: () -> Void
```

- `winBack`: the offer and its product, from the store.
- `onShowAllPlans`: a closure provided by `PaywallSheet` to switch to the regular paywall.

```swift
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPurchasing = false
    @State private var errorMessage: String?
```

- The same roles as in the custom paywall.

```swift
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.pink)
                    
                    Text("Welcome back")
                        .font(.largeTitle.bold())
                    
                    Text("Here's a special offer to rejoin StreamLab Premium.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
```

- `NavigationStack` is required for the toolbar's Close button. Everything else lives inside one `VStack`, so the spacing is consistent.

```swift
                    VStack(spacing: 6) {
                        Text(winBack.product.displayName)
                            .font(.headline)
                        Text(offerText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.background.secondary, in: .rect(cornerRadius: 12))
```

- The offer box: plan name, and the offer wording such as "$2.99/month for your first month, then $7.99/month."

```swift
                    Button {
                        Task { await claim() }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                            } else {
                                Text("Claim offer")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isPurchasing)
```

- The claim button, using the same spinner pattern as the paywall.

```swift
                    Button("See all plans", action: onShowAllPlans)
```

- Keeps the full paywall one tap away, for customers who prefer Annual or need Restore.

```swift
                    Text("After the offer, your subscription renews automatically at \(winBack.product.pricePerPeriod) unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 20) {
                        Link("Terms of Use", destination: AppLinks.termsOfUse)
                        Link("Privacy Policy", destination: AppLinks.privacyPolicy)
                    }
                    .font(.footnote)
                }
                .padding()
            }
```

- The renewal terms and legal links. Guideline 3.1.2 applies to every screen where someone can subscribe, not only the main paywall.

```swift
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .alert("Purchase failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
```

- Both are attached **inside** the `NavigationStack`. A toolbar outside it has no navigation bar to appear in, which is why the Close button was missing before the fix.

```swift
    private var offerText: String {
        let offer = winBack.offer
        let total = offer.period.value * offer.periodCount
        let unit = offer.period.unitName
        let span = total == 1 ? "your first \(unit)" : "your first \(total) \(unit)s"
        let after = "then \(winBack.product.pricePerPeriod)"
```

- `offer.period`: each discounted billing period. `periodCount`: how many of them. Multiplied, they give the total discounted time.
- `span`: "your first month" or "your first 3 months".
- `after`: the regular price that follows.

```swift
        switch offer.paymentMode {
        case .freeTrial:
            return "Free for \(span), \(after)."
        case .payUpFront:
            return "\(offer.displayPrice) for \(span), \(after)."
        default:
            return "\(offer.displayPrice)/\(offer.period.recurringText) for \(span), \(after)."
        }
    }
```

- The wording depends on how the offer charges:
  - Free.
  - Pay up front: one payment for the whole span.
  - Pay as you go (`default`): a reduced price per period, which is StreamLab's case.

```swift
    private func claim() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            if try await store.purchase(winBack.product, winBackOffer: winBack.offer) == .success {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- Buys the product **with the offer applied** (`winBackOffer:`), and closes on success. Errors show the alert.

---

## 19. Features/Account/AccountView.swift

Subscription status and management.

```swift
import SwiftUI
import StoreKit
import SwiftData
```

- `StoreKit` for `.manageSubscriptionsSheet` and `.offerCodeRedemption`.
- `SwiftData` only for the preview's `.modelContainer`.

```swift
struct AccountView: View {
    
    @Environment(SubscriptionStore.self) private var store
    
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    @State private var showOfferCode = false
    @State private var restoreMessage: String?
    @AppStorage(PaywallStyle.storageKey) private var paywallStyle = PaywallStyle.custom
```

- Three flags for the three sheets this screen can open.
- `restoreMessage` drives the restore result alert.
- `paywallStyle`: the developer setting, sharing the same key as `PaywallSheet`.

```swift
    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                manageSection
```

- A grouped `List` made of sections, built by computed properties below.

```swift
                #if DEBUG
                Section("Developer options") {
                    Picker("Paywall style", selection: $paywallStyle) {
                        ForEach(PaywallStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                }
                #endif
```

- `#if DEBUG ... #endif`: compiled only in Debug builds (running from Xcode). Release builds for TestFlight and the App Store leave it out entirely.
- `Picker`: a menu bound to `paywallStyle`. `.tag(style)` tells the picker which value each row represents.

```swift
                if let error = store.loadError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Account")
```

- Shows a product-loading error in red, if any.

```swift
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
            .manageSubscriptionsSheet(
                isPresented: $showManageSubscriptions,
                subscriptionGroupID: store.subscriptionGroupID ?? ""
            )
            .offerCodeRedemption(isPresented: $showOfferCode)
```

- `PaywallSheet`: the same paywall entry point as the detail screen.
- `.manageSubscriptionsSheet`: Apple's own subscription management, where users change plans or **cancel**. Passing the group ID focuses it on StreamLab Premium. The `?? ""` fallback only matters if products didn't load, in which case the button isn't shown anyway.
- `.offerCodeRedemption`: Apple's promo code sheet. Redemptions arrive through `Transaction.updates`.

```swift
            .alert("Restore Purchases", isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }
```

- The same message-driven alert pattern.

### Sections

```swift
    @ViewBuilder
    private var subscriptionSection: some View {
        Section("Subscription") {
            if !store.hasLoadedEntitlements {
                HStack {
                    ProgressView()
                    Text("Checking subscription...")
                        .foregroundStyle(.secondary)
                }
```

- `@ViewBuilder`: lets a computed property contain `if`/`else` branches that produce different views.
- Before the first check finishes, show "Checking" instead of guessing.

```swift
            } else if let details = store.details {
                LabeledContent("Plan", value: store.planName(for: details.productID))
                
                LabeledContent("Status") {
                    Text(statusText(for: details))
                        .foregroundStyle(statusColor(for: details))
                }
```

- `LabeledContent`: a label on the left and a value on the right, like the Settings app. One fact per row.
- Status uses a custom view so its text can be coloured.

```swift
                if let date = details.expirationDate {
                    LabeledContent(dateLabel(for: details), value: date.formatted(date: .abbreviated, time: .omitted))
                }
                
                if let next = nextPlanText(for: details) {
                    LabeledContent("Then", value: next)
                }
```

- The date row's label changes ("Trial ends", "Renews" or "Access ends"). `formatted(date:time:)` gives "Nov 1, 2026", with no time.
- "Then" appears only when the next charge is news: after a trial, or for a plan switch.

```swift
                if details.state == .inBillingRetryPeriod || details.state == .inGracePeriod {
                    Label("There's a problem with your payment method. Update it to keep Premium.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
```

- The payment warning, as Apple recommends for billing problems.

```swift
            } else {
                Label("Free plan", systemImage: "lock.fill")
                
                Button("See Premium plans") {
                    showPaywall = true
                }
            }
        }
    }
```

- No subscription: the free plan and a way into the paywall (or the win-back offer, via `PaywallSheet`).

```swift
    private var manageSection: some View {
        Section {
            if store.details != nil {
                Button("Manage Subscription") {
                    showManageSubscriptions = true
                }
            }
            
            Button("Restore Purchases") {
                Task { await restore() }
            }
            
            Button("Redeem Offer Code") {
                showOfferCode = true
            }
        }
    }
```

- Manage only appears when there's a subscription to manage. It's the in-app cancellation entry point; apps can't cancel subscriptions themselves.
- Restore and Redeem are always available.

### Helpers

```swift
    private func statusText(for details: SubscriptionDetails) -> String {
        switch details.state {
        case .inBillingRetryPeriod: return "On hold"
        case .inGracePeriod: return "Payment issue"
        default: break
        }
        
        if !details.willAutoRenew { return "Cancelled" }
        return details.isFreeTrial ? "Free trial" : "Active"
    }
```

- Payment problems take priority. `default: break` falls through to the next checks.
- Then cancelled, then trial or active.

```swift
    private func statusColor(for details: SubscriptionDetails) -> Color {
        if details.state == .inBillingRetryPeriod || details.state == .inGracePeriod {
            return .orange
        }
        return details.willAutoRenew ? .green : .secondary
    }
```

- Orange for problems, green for active or trial, grey for cancelled.

```swift
    private func dateLabel(for details: SubscriptionDetails) -> String {
        if !details.willAutoRenew { return "Access ends" }
        return details.isFreeTrial ? "Trial ends" : "Renews"
    }
```

- Picks the date row's label. The date itself is the same `expirationDate` in every case.

```swift
    private func nextPlanText(for details: SubscriptionDetails) -> String? {
        guard details.willAutoRenew else { return nil }
        
        let nextID = details.nextProductID ?? details.productID
        guard nextID != details.productID || details.isFreeTrial, let next = store.products.first(where: { $0.id == nextID }) else { return nil }
        
        return "\(next.displayName), \(next.pricePerPeriod)"
    }
```

- Cancelled users won't be charged, so there's no "Then".
- The next plan is the scheduled one, or the current one if none is set.
- Shown only for a plan switch or after a trial, and only if the product can be found.
- Example: "Annual, $59.99/year".

```swift
    private func restore() async {
        do {
            try await store.restore()
            restoreMessage = store.isSubscribed
            ? "Your subscription has been restored."
            : "No active subscription was found for this Apple Account."
        } catch {
            restoreMessage = error.localizedDescription
        }
    }
}
```

- Syncs, then reports what was found. Setting the message shows the alert.

```swift
#Preview {
    RootView()
        .environment(SubscriptionStore())
        .modelContainer(for: CachedVideo.self, inMemory: true)
}
```

- Previews the whole app with a store and an in-memory database, as in `RootView`.

---

## 20. StreamLabTests/SubscriptionStoreTests.swift

Eleven automated tests that drive StoreKit with `SKTestSession`.

```swift
import XCTest
import StoreKit
import StoreKitTest
@testable import StreamLab
```

- `XCTest`: the test framework.
- `StoreKitTest`: provides `SKTestSession`.
- `@testable import StreamLab`: gives the tests access to the app's internal types (`SubscriptionStore`, `ProductID`).

```swift
@MainActor
final class SubscriptionStoreTests: XCTestCase {
    private var session: SKTestSession!
    private var store: SubscriptionStore!
```

- `@MainActor`: the store is main-actor isolated, so the tests run there too.
- `XCTestCase`: each `test...` method is one test.
- `!` (implicitly unwrapped optionals): set in `setUp` before every test, so the tests can use them without unwrapping.

```swift
    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "StreamLab")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
```

- Runs before **each** test.
- `SKTestSession(configurationFileNamed:)`: loads `StreamLab.storekit` from the app bundle.
- Resets settings and clears purchase history, so every test starts as a new customer.
- `disableDialogs`: purchases complete without Apple's sheet, since no one is there to tap.

```swift
        store = SubscriptionStore()
        await store.loadProducts()
        await store.refreshEntitlements()
    }
```

- A fresh store, loaded exactly as at app launch.

```swift
    override func tearDown() async throws {
        session.clearTransactions()
        session = nil
        store = nil
    }
```

- Runs after each test: clears purchases and releases objects.

```swift
    private func product(_ id: String) throws -> Product {
        try XCTUnwrap(store.products.first { $0.id == id }, "Product \(id) did not load")
    }
```

- Finds a product. `XCTUnwrap` fails the test with a clear message if it's missing, instead of crashing.

```swift
    private func latestTransactionID() throws -> UInt {
        try XCTUnwrap(session.allTransactions().last?.identifier, "No transactions in the session")
    }
```

- The newest transaction's ID, needed to refund, approve or cancel it.

```swift
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
```

- Refunds and renewals reach the store through its listeners a moment later. This checks the condition every 0.1 seconds for up to 10 seconds, then fails with the given message.

### The tests

```swift
    func testProductsLoadInPriceOrderWithTrialOnMonthlyOnly() throws {
        XCTAssertEqual(store.products.map(\.id), [ProductID.monthly, ProductID.annual])

        let intro = try XCTUnwrap(try product(ProductID.monthly).subscription?.introductoryOffer)
        XCTAssertEqual(intro.paymentMode, .freeTrial)
        XCTAssertNil(try product(ProductID.annual).subscription?.introductoryOffer)
    }
```

- Both products load, sorted Monthly then Annual. `map(\.id)` extracts the IDs.
- Monthly has a free-trial intro offer; Annual has none.

```swift
    func testNewCustomerIsLocked() {
        XCTAssertTrue(store.hasLoadedEntitlements)
        XCTAssertFalse(store.isSubscribed)
        XCTAssertNil(store.details)
        XCTAssertFalse(store.canWatch(isPremium: true))
        XCTAssertTrue(store.canWatch(isPremium: false))
    }
```

- A new customer: checked, not subscribed, no details, locked out of premium, allowed free titles.

```swift
    func testPurchaseUnlocksPremiumWithFreeTrial() async throws {
        let outcome = try await store.purchase(try product(ProductID.monthly))

        XCTAssertEqual(outcome, .success)
        XCTAssertEqual(store.activeProductID, ProductID.monthly)
        XCTAssertTrue(store.canWatch(isPremium: true))
        XCTAssertEqual(store.details?.isFreeTrial, true, "A new customer's first Monthly period is the free trial")
    }
```

- A purchase succeeds, unlocks premium, and starts with the free trial.

```swift
    func testFailedPurchaseKeepsUserLocked() async throws {
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)

        do {
            _ = try await store.purchase(try product(ProductID.monthly))
            XCTFail("Expected the purchase to throw")
        } catch {
            XCTAssertFalse(store.isSubscribed)
        }
    }
```

- `setSimulatedError`: makes the next purchase fail. The test passes only if the purchase throws and the user stays locked. `XCTFail` catches the case where it wrongly succeeds.

```swift
    func testAskToBuyIsPendingUntilApproved() async throws {
        session.askToBuyEnabled = true

        let outcome = try await store.purchase(try product(ProductID.monthly))
        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(store.isSubscribed)

        try session.approveAskToBuyTransaction(identifier: try latestTransactionID())
        try await waitUntil("approval unlocks premium") { store.isSubscribed }
    }
```

- With Ask to Buy on, the purchase is pending and locked. Approving it unlocks premium through the `Transaction.updates` listener.

```swift
    func testRefundRevokesAccess() async throws {
        _ = try await store.purchase(try product(ProductID.monthly))
        XCTAssertTrue(store.isSubscribed)

        try session.refundTransaction(identifier: try latestTransactionID())
        try await waitUntil("refund revokes access") { !store.isSubscribed }
    }
```

- A refund removes access without a relaunch.

```swift
    func testPurchaseMadeOutsideTheAppIsPickedUp() async throws {
        _ = try await session.buyProduct(identifier: ProductID.annual)
        try await waitUntil("outside purchase unlocks premium") { store.activeProductID == ProductID.annual }
    }
```

- `session.buyProduct` purchases without going through our store, as if on another device. The listener still picks it up.

```swift
    func testRenewalKeepsAccessAndEndsTrial() async throws {
        _ = try await store.purchase(try product(ProductID.monthly))
        XCTAssertEqual(store.details?.isFreeTrial, true)

        try session.forceRenewalOfSubscription(productIdentifier: ProductID.monthly)
        try await waitUntil("renewal starts a paid period") { store.details?.isFreeTrial == false }
        XCTAssertTrue(store.isSubscribed)
    }
```

- Forcing a renewal keeps access, and the new period is paid, not the trial.

```swift
    func testCancellingTurnsOffAutoRenewButKeepsAccess() async throws {
        _ = try await store.purchase(try product(ProductID.monthly))
        XCTAssertEqual(store.details?.willAutoRenew, true)

        try session.disableAutoRenewForTransaction(identifier: try latestTransactionID())
        try await waitUntil("cancellation shows in details") { store.details?.willAutoRenew == false }
        XCTAssertTrue(store.isSubscribed, "A cancelled subscription keeps access until it expires")
    }
```

- Cancelling (auto-renew off) shows in the details, while access continues until expiry.

```swift
    func testRestoreKeepsExistingSubscription() async throws {
        _ = try await store.purchase(try product(ProductID.monthly))

        try await store.restore()
        XCTAssertEqual(store.activeProductID, ProductID.monthly)
    }
```

- Restore leaves a valid subscription in place.

```swift
    func testLapsedSubscriberIsOfferedWinBack() async throws {
        session.timeRate = .monthlyRenewalEveryThirtySeconds

        _ = try await store.purchase(try product(ProductID.monthly))
        XCTAssertNil(store.winBackOffer, "Active subscribers never see a win-back offer")
```

- `timeRate`: a month passes in 30 seconds, so the one-week trial lasts about 7 seconds.
- While subscribed, there's no offer.

```swift
        // Cancel, then let the subscription run out on its own.
        try session.disableAutoRenewForTransaction(identifier: try latestTransactionID())
        try await waitUntil(timeout: 30, "the subscription lapses and a win-back offer appears") {
            store.winBackOffer != nil
        }
```

- Cancel, then wait (up to 30 seconds) for natural expiry and the offer to appear. This also proves expiry is detected automatically.

```swift
        XCTAssertFalse(store.isSubscribed, "Content locks once the subscription expires")
        XCTAssertEqual(store.winBackOffer?.offer.id, "winback.monthly.first")
        XCTAssertEqual(store.winBackOffer?.product.id, ProductID.monthly)
    }
}
```

- After lapsing: content is locked, and the offer is the configured `winback.monthly.first` on Monthly.

---

## 21. StreamLabTests/StreamLabTests.swift

```swift
import XCTest
@testable import StreamLab

final class StreamLabTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. ...
    }

    override func tearDownWithError() throws {
        // Put teardown code here. ...
    }

    func testExample() throws {
        // This is an example of a functional test case. ...
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
```

- The template file Xcode created with the project. `testExample` is empty; `testPerformanceExample` uses `measure` to time an empty block. **Note:** neither tests anything; see the review notes.

---

## 22. Resources and other files

| File | What it is |
|---|---|
| `Resources/StreamLab.storekit` | The local StoreKit configuration: the "StreamLab Premium" group, Monthly ($7.99, 7-day free trial, $2.99 win-back offer), Annual ($59.99). Used when running from Xcode and by the tests. |
| `Resources/Assets.xcassets` | The asset catalog: the app icon and accent colour slots (currently empty, so system defaults are used). |
| `catalog.json` | The video list the app downloads from GitHub. |
| `PRIVACY.md` | The privacy policy the paywalls link to. |
| `README.md` | The project overview for GitHub. |
| `docs/screenshots/` | The README's images. |
| `StreamLab.xcodeproj/xcshareddata/xcschemes/StreamLab.xcscheme` | The shared scheme. Its Run action points StoreKit at `StreamLab/Resources/StreamLab.storekit`. |
| `.gitignore` | Keeps user-specific Xcode files and build output out of git. |
| `StreamLabUITests/` | Xcode's template UI tests. Not used by StreamLab. |

---

## 23. Review notes

The code is correct and builds cleanly. These are the small things worth tidying, in order of usefulness:

1. **Debug `print` in `SubscriptionStore.handle(_:)`.** Useful while learning, but production code normally uses `Logger` from `os`, which can be filtered and is stripped of private data, or removes it.
2. **Template test file.** `StreamLabTests.swift` tests nothing. Delete it, so the test count reflects real tests.
3. **Test target minimum iOS is 27.0** while the app's is 18.0. Lowering the test target to 18.0 lets the tests run on the same OS versions the app supports.
4. **`Video` is `Hashable` but doesn't need to be.** Navigation uses `CachedVideo`. Harmless; it could be removed.
5. **Formatting in `StoreKitPaywallView`.** The two `.subscriptionStorePolicyDestination` calls have unusual line breaks. Select all and press **Ctrl+I** in Xcode to re-indent, or write each call on one line.
6. **Small spacing details.** `defer { isLoading = false}` in `HomeView` is missing a space before `}`, and `_ result:VerificationResult` in `handle` is missing a space after the colon. Cosmetic only.
7. **Overlapping refreshes.** Several triggers (a listener, the expiry timer, a purchase) can call `refreshEntitlements()` close together. Each run reads fresh state from StoreKit and ends correct, so this is fine at StreamLab's scale. In a larger app you might coalesce refreshes.
8. **Known gap in the tests.** Applying the win-back price isn't covered by an automated test, because the test environment applied the free trial instead (see Lesson 13). It's verified manually in Xcode's Manage Transactions window.
