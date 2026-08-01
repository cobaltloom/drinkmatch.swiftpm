import Foundation

/// Fill these in from your Supabase project dashboard (Project Settings >
/// API). The anon/publishable key is safe to ship in the client — it only
/// grants what Row Level Security allows (see drinkmatch-backend's
/// `supabase/migrations`). Never put the service_role key here.
enum SupabaseConfig {
    static let projectURL = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    static let publishableKey = "YOUR-ANON-OR-PUBLISHABLE-KEY"

    /// Set once these are filled in; RootView uses this to show a setup
    /// notice instead of silently failing every network call.
    static var isConfigured: Bool {
        projectURL.host?.contains("YOUR-PROJECT-REF") == false && !publishableKey.hasPrefix("YOUR-")
    }
}
