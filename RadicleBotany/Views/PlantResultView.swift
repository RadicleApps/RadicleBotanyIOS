import SwiftUI

struct PlantResultView: View {
    let result: PlantIdentificationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bestMatch = result.bestMatch {
                Text(bestMatch.commonName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(bestMatch.scientificName)
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)

                HStack {
                    Text("Confidence:")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", bestMatch.score * 100))
                        .fontWeight(.semibold)
                        .foregroundColor(bestMatch.score > 0.5 ? .green : .orange)
                }
            } else {
                Text("No match found")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
