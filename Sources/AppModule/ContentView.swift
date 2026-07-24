import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Button("OK") {
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
