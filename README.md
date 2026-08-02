# drinkmatch (CREW BOARD)

Airline-crew drink-matching app. A SwiftUI Swift Playgrounds App project
(this repo root is the `.swiftpm` package) backed by the
[drinkmatch-backend](https://github.com/translate5jp/drinkmatch-backend)
Supabase project.

## Status

Full UI is wired to real network calls (`Sources/AppModule/Networking`,
`Sources/AppModule/Store/AppStore.swift`) against the Supabase schema/RPCs in
drinkmatch-backend. This has **not** been compiled or run against a live
project — this repo was built in a Linux sandbox with no Xcode/Swift
toolchain and no live Supabase project to test against. Open it in Swift
Playgrounds or Xcode and expect to fix minor build issues, especially around
the `supabase-swift` package version (its API moves between releases).

Billing (`Billing/StoreKitManager.swift`, `PaywallGateView`) is equally
unverified, and untested for a reason beyond the usual toolchain gap: there
was no way to generate an Xcode StoreKit Testing configuration file (the
usual way to try a purchase flow in the simulator without live App Store
Connect products) without Xcode itself. Test this one first, with a Sandbox
tester account, once you have a toolchain — see "Setup" below and
drinkmatch-backend's README "Billing".

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
   Signing & Capabilities > + Capability > Sign in with Apple.
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
7. For push notifications to actually arrive: enable the **Push
   Notifications** capability (Xcode: Target > Signing & Capabilities > +
   Capability > Push Notifications — check whether Swift Playgrounds
   exposes this the same way it doesn't for Sign in with Apple above), and
   deploy + configure drinkmatch-backend's `deliver-push-notification`
   function per its README "Push notifications". Without that, permission
   requests and device-token registration still work, but nothing is
   listening on the other end to actually send anything.

## Architecture

- `Sources/AppModule/Networking/` — `SupabaseConfig`/`SupabaseManager` (the
  shared client), `DTOs.swift` (request/response types — see its header
  comment on why every field has an explicit `CodingKeys`, not automatic
  snake_case conversion), `SupabaseRepository.swift` (all actual network
  calls), `NetworkConversions.swift` (day-of-month ↔ SQL `date`, "HH:mm" ↔
  SQL `time`, and backend error-code matching).
- `Sources/AppModule/Store/AppStore.swift` — `@MainActor @Observable` app
  state and the async operations views call; owns auth session tracking via
  `SupabaseManager.client.auth.authStateChanges`, and (started as a second,
  independent `.task` from RootView) a `Transaction.updates` loop that keeps
  subscription state in sync with StoreKit.
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
  drinkmatch-backend).
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
- **Push notifications.** `MainView` now requests permission and registers
  the device token every time it appears (harmless no-op once already
  granted/registered) — `Notifications/AppDelegate.swift` bridges UIKit's
  `didRegisterForRemoteNotificationsWithDeviceToken` into SwiftUI (there's
  no App-protocol equivalent), `PushNotificationManager` turns the token
  into the hex string `push_tokens` expects, and `AppStore.enablePushNotifications`
  writes it via `SupabaseRepository.registerPushToken`. Actual delivery is
  drinkmatch-backend's `deliver-push-notification` Edge Function — see its
  README "Push notifications".

## Not done yet

- Editing your own airline/years-of-service/note — the onboarding form never
  collected these, even though the backend and other users' cards support
  them.
