import Foundation

/// Fill these in from your Supabase project dashboard (Project Settings >
/// API). The anon/publishable key is safe to ship in the client — it only
/// grants what Row Level Security allows (see drinkmatch-backend's
/// `supabase/migrations`). Never put the service_role key here.
enum SupabaseConfig {
    static let projectURL = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    static let publishableKey = "YOUR-ANON-OR-PUBLISHABLE-KEY"

    /// Flip this alongside projectURL/publishableKey every time you point
    /// this build at a different Supabase project. Unlike the URL/key
    /// themselves, this can't be inferred (both a prod and a test project
    /// are just some arbitrary "https://<ref>.supabase.co", so there's no
    /// pattern to detect) — it's a deliberate, separate switch specifically
    /// so a build can't silently be "test" or "production" by accident.
    /// RootView shows a persistent warning banner whenever this is `.test`.
    static let environment: Environment = .production

    enum Environment {
        case production
        case test
    }

    /// Set once projectURL/publishableKey are filled in; RootView uses this
    /// to show a setup notice instead of silently failing every network call.
    static var isConfigured: Bool {
        projectURL.host?.contains("YOUR-PROJECT-REF") == false && !publishableKey.hasPrefix("YOUR-")
    }
}
