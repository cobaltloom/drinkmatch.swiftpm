import Foundation
import Supabase

/// One shared client per Supabase's own guidance ("create one instance per
/// Supabase project and share it across your app").
enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.projectURL,
        supabaseKey: SupabaseConfig.publishableKey
    )
}
