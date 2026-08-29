# drinkmatch (CrewBoard)

Airline-crew drink-matching app. A SwiftUI app backed by the
[drinkmatch-backend](https://github.com/cobaltloom/drinkmatch-backend)
Supabase project. Originally a Swift Playgrounds App project (repo root as
the `.swiftpm` package); converted to a standard Xcode project
(`DrinkMatch.xcodeproj`, app code under `DrinkMatch/AppModule`) once Mac
access was available, specifically to add the Sign In with Apple
capability — see "Sign in with Apple" below.

## Member groups

MainView has a "1対1" / "グループ" switcher (`ContactMode`, independent of
the friends/strangers `MatchMode` within the 1-on-1 side) alongside the
existing 1-on-1 matching. `GroupsTabView` lets a user create a persistent
group, join one via its invite code (instant, no approval), or accept an
invite from an existing member (`IncomingMemberGroupInvitesView` —
requires the inviter and invitee already be friends, and needs the
invitee's acceptance, mirroring the friend-request flow). Selecting a
group in `GroupsTabView`'s sidebar shows `MemberGroupDetailView`: the
roster, an invite-a-friend picker, and the group's schedule ranking — every
day+airport at least two members share a stay for, most members-free-
together first (`DrinkMatchStore.loadMemberGroupScheduleRanking`, backed by
drinkmatch-backend's `get_member_group_schedule_ranking`). This is
distinct from `GroupOffer`/group offers, a one-shot invitation tied to a
single already-chosen day/airport.

## Status

Full UI is wired to real network calls against the Supabase schema/RPCs in
drinkmatch-backend, and has been exercised end-to-end on a real iPad via
Swift Playgrounds (no Mac): sign-in, session persistence across relaunch,
schedule entry, referral-code issue/redeem, friend invite codes, sending and
accepting offers, report, block/unblock, and account deletion (including the
referral-issuer/redeemer deletion paths — see "Behavior changes from the
prototype" below) all confirmed working against the real
`drinkmatch-backend` project.

**Sign-in is Sign in with Apple only** (Supabase Auth's `id_token` grant —
see `AuthManager.signInWithApple` and `AppleNonceGenerator`). It was
dropped for a long stretch of this project's history: Swift Playgrounds'
`.iOSApplication` project format has no way to add the capability at
all — confirmed against Apple's own list of supported App Playground
capabilities
(`developer.apple.com/documentation/swift-playgrounds/project-capabilities`),
which has no Sign in with Apple entry, and later reconfirmed directly in
Xcode's Signing & Capabilities editor, which never offered it for that
project format regardless of team/signing state. Working around that with
CI on a macOS runner (a hand-injected entitlement, building headlessly)
ran into its own Apple Developer certificate-quota problems and was
abandoned too. The capability only became addable once this repo
converted to a standard Xcode project (see "Status" above) — at that
point Xcode's "+ Capability" search actually found it.

The app originally shipped with email/password sign-in alongside Sign in
with Apple (Apple's Guideline 4.8 never required Apple sign-in here, since
no other third-party login was offered — it was purely a convenience).
Email/password was removed once Sign in with Apple was verified working
end-to-end and there were still zero real users to migrate: every user of
this iOS-only, App Store-distributed app already has an Apple ID, so
there's no coverage gap, and it eliminates password reset/storage
entirely.

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
   this is done (`SupabaseConfig.isConfigured`). If you're running two
   Supabase projects (a production one plus a separate one for testing —
   recommended once real users are involved, since it keeps test data out of
   production and vice versa), also set `SupabaseConfig.environment` to
   match (`.production` / `.test`) every time you point the build at a
   different project. It's a separate, deliberate switch rather than
   something inferred from the URL — nothing distinguishes a prod project's
   URL from a test project's by pattern — and `.test` makes RootView show a
   permanent red "TEST ENVIRONMENT" banner over the whole app so a test
   build can never be mistaken for production, or vice versa.
3. Open `DrinkMatch.xcodeproj` in Xcode and build/run. First launch: sign
   in with Apple → profile setup → schedule setup → main board.
4. For the "新しい人を探す" paywall to show a real price and accept
   purchases: sign the Paid Applications Agreement in App Store Connect,
   then create an auto-renewable subscription product there with an ID
   matching `subscriptionProductID` in
   `Sources/AppModule/Data/ReferenceData.swift`. See drinkmatch-backend's
   README "Billing" for the server side (`verify-purchase` /
   `app-store-notifications` Edge Functions) that has to be deployed for a
   purchase to actually stick — without it, `PaywallGateView` will show the
   real price and let a purchase go through in Sandbox, but `isSubscribed`
   will never flip because nothing is verifying/recording it server-side.
5. Push notifications need server-side setup before they actually deliver —
   see "Not done yet" and drinkmatch-backend's README "Push notifications".

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
- `Sources/AppModule/Store/DrinkMatchStore.swift` — `@MainActor @Observable` app
  state and the async operations views call; checks for a persisted session
  at launch (`bootstrap()`) rather than listening to a continuous
  auth-state stream (there isn't one without the SDK), and (started as a
  second, independent `.task` from RootView) runs a `Transaction.updates`
  loop that keeps subscription state in sync with StoreKit.
- `Sources/AppModule/Billing/StoreKitManager.swift` — the StoreKit 2 side of
  purchasing/restoring the subscription; `DrinkMatchStore` owns the resulting state
  and calls `SupabaseRepository.verifyPurchase` to have
  drinkmatch-backend's `verify-purchase` Edge Function confirm the purchase
  before `isSubscribed` actually flips (StoreKit alone can't be trusted for
  that — see drinkmatch-backend's README "Billing").
- `Sources/AppModule/Notifications/` — `AppDelegate.swift` (the
  `@UIApplicationDelegateAdaptor` bridge in `DrinkMatchApp.swift` needs for
  `didRegisterForRemoteNotificationsWithDeviceToken` — SwiftUI's App
  protocol has no equivalent) and `PushNotificationManager.swift` (turns
  the resulting token into what `DrinkMatchStore.enablePushNotifications` sends to
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
  Blocking calls `DrinkMatchStore.blockUser`, which removes the person from
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
  calls `DrinkMatchStore.deleteAccount()` → drinkmatch-backend's
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
- **Age-difference filter in "新しい人を探す".** `ProfileSetupView` has an
  optional "生まれ年" (birth year, not full birthdate) field, and
  `StrangersSearchView` (in `StrangersTabView.swift`) has a 5歳/7歳/10歳
  以内/気にしない filter menu next to the existing same-company one, same
  client-side pattern: candidates are compared against the signed-in
  user's own birth year, and a candidate with no birth year on file (or a
  caller with none) is excluded rather than assumed to match, once
  anything but "気にしない" is selected. Requires
  drinkmatch-backend's `20260801000016_stranger_age_filter.sql`
  (`supabase db push`, or paste it into the Dashboard SQL editor) to be
  applied before `birth_year` exists to read/write.
- **Candidate-count preview on the paywall.** New-person search has a
  cold-start problem: with few users, "pay before finding out if anyone's
  even there" is a hard sell. `PaywallGateView` now shows "現在、予定が
  重なる新しい人がN人います" (or an encouraging message at zero) before
  the user subscribes, via `DrinkMatchStore.loadStrangerCandidateCount()`
  → drinkmatch-backend's `count_stranger_candidates()`, which mirrors
  `search_stranger_candidates`'s own filters minus the subscription
  requirement — a real count, not an inflated estimate, since a candidate
  has never needed to be subscribed themselves to be found. Fails silently
  (no error shown) if the count can't load, since it's a nice-to-have, not
  required to use the app. Requires drinkmatch-backend's
  `20260801000017_stranger_candidate_count.sql` to be applied.

## Not done yet

- **Push notifications — client side wired up, server side not yet
  deployed.** `Notifications/AppDelegate.swift` + `PushNotificationManager.swift`
  + `DrinkMatchStore.enablePushNotifications` (called from `MainView`'s
  `.task`) register the device token to `push_tokens` via
  `SupabaseRepository.registerPushToken`. The Push Notifications capability
  (`aps-environment` in `DrinkMatch.entitlements`) needed Xcode to add —
  the same class of problem Sign in with Apple turned out to be (see
  "Status") — and is unblocked the same way, now that this repo is a
  standard Xcode project. Still needed before this actually delivers a
  push: drinkmatch-backend's `deliver-push-notification` Edge Function
  deployed with real APNs credentials, and its Database Webhook configured
  — see that repo's README "Push notifications" "Setup". Entirely
  unverified end-to-end (needs a real device — the simulator can't
  register for real APNs tokens).
- Editing your own airline/years-of-service/note — the onboarding form never
  collected these, even though the backend and other users' cards support
  them.
