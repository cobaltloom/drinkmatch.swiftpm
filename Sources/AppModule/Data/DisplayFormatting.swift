import Foundation

func airportName(_ code: String) -> String {
    StayAirports.all.first { $0.code == code }?.name ?? code
}

func airportLabel(_ code: String) -> String {
    "\(code) (\(airportName(code)))"
}

func airlineName(_ code: String) -> String {
    Airlines.all.first { $0.code == code }?.name ?? code
}

func airlineLabel(_ code: String) -> String {
    "\(code) (\(airlineName(code)))"
}

func initials(from fullName: String) -> String {
    let parts = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
        .map(String.init)
        .filter { !$0.isEmpty }
    guard !parts.isEmpty else { return "" }
    return parts.map { String($0.prefix(1)).uppercased() }.joined(separator: ".") + "."
}
