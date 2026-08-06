# drinkmatch (CREW BOARD)

Airline-crew drink-matching app. A SwiftUI Swift Playgrounds App project
(this repo root is the `.swiftpm` package) backed by the
[drinkmatch-backend](https://github.com/translate5jp/drinkmatch-backend)
Supabase project.

## Status

Full UI is wired to real network calls against the Supabase schema/RPCs in
drinkmatch-backend, and has been exercised end-to-end on a real iPad via
Swift Playgrounds (no Mac): sign-in, session persistence across relaunch,
schedule entry, referral-code issue/redeem, friend invite codes, sending and
accepting offers, report, block/unblock, and account deletion (including the
referral-issuer/redeemer deletion paths — see "Behavior changes from the
prototype" below) all confirmed working against the real
`drinkmatch-backend` project.

**Sign in with Apple cannot be tested with this project's current Apple
account.** The "Sign In with Apple" capability — and Push Notifications,
below — can only be granted to an App ID under a **paid** Apple Developer
Program membership ($99/yr); this account is still on the free tier, where
`developer.apple.com`'s Identifiers/Certificates pages aren't even
reachable. This isn't a Swift Playgrounds-specific limitation like the SDK
issue below — Xcode would hit the same wall. Until the membership is bought,
`SignInView` has a temporary dev-only email/password sign-in block (GoTrue's
plain `/auth/v1/signup` / `/auth/v1/token?grant_type=password`) alongside
the real Apple button, which is what all the testing above actually used.
**Delete that block once Apple sign-in is testable** — see its comment in
`Sources/AppModule/Screens/SignInView.swift`.

**This does not use the official `supabase-swift` SDK.** It was tried
first and turned out to be impossible to build in Swift Playgrounds: the
SDK depends transitively on `swift-crypto`, which has C-language targets
(`CCryptoBoringSSL`, `CXKCP`), and Swift Playgrounds categorically refuses
to build any SPM package containing a C/C++/Objective-C target — confirmed
via Apple's own developer forums, a hard platform limitation with no
workaround short of Xcode. `Sources/AppModule/Networking/` instead talks to
Supabase's REST APIs (PostgREST, GoTrue, Edge Functions) directly over
`URLSession` — see "Architecture" below. `RestClient.swift`'s header
comment has the full explanation.

Billing (`Billing/StoreKitManager.swift`, `PaywallGateView`) builds cleanly
(fixed a `Transaction` vs. `VerificationResult<Transaction>.jwsRepresentation`
compile error along the way) but is still untested end-to-end, plus a
StoreKit-specific gap: there was no way to generate an Xcode StoreKit
Testing configuration file (the usual way to try a purchase flow in the
simulator without live App Store Connect products) without Xcode itself.
Test this one with a Sandbox tester account — see "Setup" below and
drinkmatch-backend's README "Billing". Note Sandbox testing itself likely
also needs the paid Developer Program membership mentioned above, via App
Store Connect.

## Setup

1. Follow drinkmatch-backend's README to provision a Supabase project and
   apply its migrations.
2. Open `Sources/AppModule/Networking/SupabaseConfig.swift` and fill in your
   project's URL and anon/publishable key (Dashboard > Project Settings >
   API). The app shows a setup notice screen instead of the real UI until
   this is done (`SupabaseConfig.isConfigured`).
3. In Supabase Dashboard > Authentication > Providers, enable **Apple** as a
   sign-in provider, and add your app's bundle identifier
   (`com.translate5jp.DrinkMatch`, see `Package.swift`) to its Client IDs
   list — required for the native `signInWithIdToken` flow this app uses
   (see [Supabase's Apple login guide](https://supabase.com/docs/guides/auth/social-login/auth-apple),
   "native sign-in" section).
4. Enable the **Sign in with Apple** capability for this project. Unlike
   most capabilities, this isn't set in `Package.swift` — Swift Playgrounds
   doesn't expose a `ProductSetting.IOSAppInfo.Capability` case for it. In
   Swift Playgrounds on iPad: open this project's settings and enable Sign
   in with Apple there (requires being signed into an Apple Developer
   account with an App ID that has the capability enabled — Playgrounds can
   provision this automatically once you're signed in). In Xcode: Target >
   Signing & Capabilities > + Capability > Sign in with Apple. **This
   requires a paid Apple Developer Program membership** — a free account
   can't reach the Identifiers/Certificates pages needed to grant the
   capability at all (see "Status"). Until enrolled, use the temporary
   dev-only email/password sign-in in `SignInView` instead.
5. Build and run. First launch: Sign in with Apple → profile setup →
   schedule setup → main board.
6. For the "新しい人と探す" paywall to show a real price and accept
   purchases: sign the Paid Applications Agreement in App Store Connect,
   then create an auto-renewable subscription product there with an ID
   matching `subscriptionProductID` in
   `Sources/AppModule/Data/ReferenceData.swift`. See drinkmatch-backend's
   README "Billing" for the server side (`verify-purchase` /
   `app-store-notifications` Edge Functions) that has to be deployed for a
   purchase to actually stick — without it, `PaywallGateView` will show the
   real price and let a purchase go through in Sandbox, but `isSubscribed`
   will never flip because nothing is verifying/recording it server-side.
7. Push notifications are on hold — see "Not done yet".

## Architecture

- `Sources/AppModule/Networking/` — no `supabase-swift` SDK (see "Status");
  everything talks to Supabase's plain REST APIs via `URLSession`:
  - `SupabaseConfig.swift` — project URL + publishable key.
  - `RestClient.swift` — the raw HTTP layer (headers, error decoding, the
    `eq`/`inList` PostgREST filter-query-item helpers). Its header comment
    explains why this exists instead of the SDK.
  - `PostgREST.swift` — table (select/insert/update/delete/upsert) and RPC
    helpers built on RestClient, covering every shape SupabaseRepository
    needs, plus Edge Function invocation.
  - `AuthSessionData.swift` / `KeychainStore.swift` / `AuthManager.swift` —
    the hand-rolled equivalent of the SDK's session management: persists
    the session in the Keychain between launches, and — as an `actor`,
    specifically to serialize concurrent callers — refreshes the access
    token before it expires. Supabase's refresh tokens rotate on every use,
    so two callers racing to refresh at once would have the second one fail
    against an already-invalidated token; the actor collapses concurrent
    refreshes into one in-flight request everyone awaits instead.
  - `DTOs.swift` (request/response types — see its header comment on why
    every field has an explicit `CodingKeys`, not automatic snake_case
    conversion — this predates the SDK removal but the reasoning holds
    regardless: PostgREST speaks the database's actual snake_case column
    names on the wire either way), `SupabaseRepository.swift` (all actual
    network calls — same public API before and after the SDK was removed,
    so nothing outside this folder changed), `NetworkConversions.swift`
    (day-of-month ↔ SQL `date`, "HH:mm" ↔ SQL `time`, and backend
    error-code matching).
- `Sources/AppModule/Store/AppStore.swift` — `@MainActor @Observable` app
  state and the async operations views call; checks for a persisted session
  at launch (`bootstrap()`) rather than listening to a continuous
  auth-state stream (there isn't one without the SDK), and (started as a
  second, independent `.task` from RootView) runs a `Transaction.updates`
  loop that keeps subscription state in sync with StoreKit.
- `Sources/AppModule/Billing/StoreKitManager.swift` — the StoreKit 2 side of
  purchasing/restoring the subscription; `AppStore` owns the resulting state
  and calls `SupabaseRepository.verifyPurchase` to have
  drinkmatch-backend's `verify-purchase` Edge Function confirm the purchase
  before `isSubscribed` actually flips (StoreKit alone can't be trusted for
  that — see drinkmatch-backend's README "Billing").
- `Sources/AppModule/Notifications/` — `AppDelegate.swift` (the
  `@UIApplicationDelegateAdaptor` bridge in `DrinkMatchApp.swift` needs for
  `didRegisterForRemoteNotificationsWithDeviceToken` — SwiftUI's App
  protocol has no equivalent) and `PushNotificationManager.swift` (turns
  the resulting token into what `AppStore.enablePushNotifications` sends to
  drinkmatch-backend). Built but not currently wired up to any view — see
  "Not done yet".
- `Sources/AppModule/Screens/`, `Components/` — unchanged in structure from
  the original mock-data build; several were adjusted where the real
  backend's privacy/authorization model didn't match the prototype's looser
  single-session assumptions (see "Behavior changes from the prototype"
  below).

## Behavior changes from the prototype

Wiring up a real multi-user backend surfaced a few places where the
mock-data prototype's UI didn't (and couldn't) match real constraints:

- **Offers are now tied to one specific day + airport at creation time**
  (matching the handoff doc's `OFFERS` table), not "I want to meet this
  person" in the abstract. `PersonCardView` now shows a "🍻 誘う" button per
  overlapping day instead of one ambiguous button per person.
- **The "(デモ)相手が承諾したことにする" / "(デモ)承諾させる" buttons are
  gone.** They let the prototype's single browser session simulate *anyone*
  accepting, which doesn't correspond to any real capability — `accept_offer`
  and `accept_group_offer_membership` are scoped to the actual recipient's
  own account server-side. An incoming pending offer now shows a real
  "承諾する" button instead; a group member only sees an accept button on
  their own row.
- **Users can now generate their own invite code** (`InviteCodeGeneratorView`
  in the friends tab). The prototype only had pre-seeded mock codes issued by
  other mock users — there was never a way for a real user to produce one to
  hand to a friend.
- **The schedule board's active month is now real, not a frozen demo
  value.** `BoardCalendar.year`/`.month` used to be hardcoded to July 2026,
  mirroring the mock-data prototype. It's now computed from the actual
  date — before the 25th, the current month; from the 25th onward, next
  month (matching when airlines typically finalize next month's crew
  schedule) — fixed for the app's process lifetime and used app-wide (offer/
  proposal creation, other users' displayed stay days). `ScheduleSetupView`
  additionally has its own independently navigable month (prev/next
  buttons) for browsing/editing other months without shifting that app-wide
  default underfoot; `fetchSchedule` is now filtered to one real month at a
  time so two different months' entries can't collide on the same
  day-of-month number (`StayEntry.day` is still just a bare `Int`).
- **"見送る" (pass) persists server-side** (`passed_candidates` table)
  instead of only living in local component state, so it survives across
  devices/reinstalls.
- **Report/block** (App Store Review Guideline 1.2 — required for any app
  with user-to-user interaction): a flag icon on `PersonCardView` and on a
  match's detail pane in `MatchesView` opens `ReportBlockSheet` (reason
  picker + optional details, plus an independent "ブロックする" action).
  Blocking calls `AppStore.blockUser`, which removes the person from
  friends/candidates/matches locally and from every enforcement point
  server-side (`is_blocked`, see drinkmatch-backend's README "Report/block").
  Blocked users are managed from MainView's overflow menu →
  "ブロック中のユーザー" (`BlockedUsersView`), which can unblock.
- **The "(デモ)購入して新しい人と探す" button is gone.** `PaywallGateView`
  now shows the subscription's real StoreKit price and does a real
  purchase, verified server-side (see "Architecture" above) — plus a
  "購入を復元" restore-purchases button, required by App Store guidelines
  for any subscription.
- **Account deletion** (App Store Review Guideline 5.1.1(v) — required for
  any app with account creation): MainView's overflow menu →
  "アカウントを削除" opens `DeleteAccountView`, a confirmation screen that
  calls `AppStore.deleteAccount()` → drinkmatch-backend's
  `delete_own_account()` RPC, then signs out locally (deleting the row
  server-side doesn't itself invalidate the client's session token). See
  drinkmatch-backend's README "Account deletion" for the cascade and a
  couple of foreign-key bugs that fix uncovered.
- **Age/alcohol-guideline confirmation.** `ProfileSetupView` now has a
  required checkbox ("私は20歳以上であり…") that must be checked before
  "プロフィールを作成して始める" enables — `create_profile`'s new required
  `p_age_confirmed` parameter rejects the call server-side even if it
  somehow wasn't. This is Japan's legal drinking age (20), not the general
  age of majority (18 since 2022) — see drinkmatch-backend's README
  "Age/alcohol-guideline confirmation".

## Not done yet

- **Push notifications — implemented but disabled.**
  `Notifications/AppDelegate.swift` + `PushNotificationManager.swift` +
  `AppStore.enablePushNotifications` are a complete, working device-token
  registration path (writes to `push_tokens` via
  `SupabaseRepository.registerPushToken`, which drinkmatch-backend's
  `deliver-push-notification` Edge Function reads — see its README "Push
  notifications"), but nothing calls `enablePushNotifications()` — it's
  disabled at the one call site that used to exist in `MainView`. Reason:
  the Push Notifications capability needs Apple's `aps-environment`
  entitlement, which **Swift Playgrounds cannot add** (confirmed via
  Apple's own developer forums — it requires Xcode, i.e. a Mac) **and which
  also requires a paid Apple Developer Program membership** regardless of
  Xcode access (see "Status") — this project's account is still on the free
  tier. This project has been developed without Mac access. Re-add
  `.task { await store.enablePushNotifications() }` to `MainView` once
  that capability can actually be granted; nothing else needs to change.
- Editing your own airline/years-of-service/note — the onboarding form never
  collected these, even though the backend and other users' cards support
  them.
