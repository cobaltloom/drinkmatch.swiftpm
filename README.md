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

## Architecture

- `Sources/AppModule/Networking/` — `SupabaseConfig`/`SupabaseManager` (the
  shared client), `DTOs.swift` (request/response types — see its header
  comment on why every field has an explicit `CodingKeys`, not automatic
  snake_case conversion), `SupabaseRepository.swift` (all actual network
  calls), `NetworkConversions.swift` (day-of-month ↔ SQL `date`, "HH:mm" ↔
  SQL `time`, and backend error-code matching).
- `Sources/AppModule/Store/AppStore.swift` — `@MainActor @Observable` app
  state and the async operations views call; owns auth session tracking via
  `SupabaseManager.client.auth.authStateChanges`.
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

## Not done yet

- StoreKit 2 purchase flow + the App Store Server Notifications webhook —
  "(デモ)購入して新しい人と探す" still just flips a local flag and doesn't
  persist (see drinkmatch-backend's README "Billing").
- APNs push delivery — notifications only show in-app.
- Age/alcohol-guideline confirmation at signup.
- Editing your own airline/years-of-service/note — the onboarding form never
  collected these, even though the backend and other users' cards support
  them.
- Account deletion.
