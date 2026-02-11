import Foundation
import UIKit

enum PlantNetError: LocalizedError {
    case invalidImage
    case networkError(String)
    case decodingError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image."
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Failed to parse response: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

class PlantNetService {
    static let shared = PlantNetService()

    private let baseURL = "https://my-api.plantnet.org/v2/identify/all"

    private lazy var apiKey: String = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let key = config["PLANTNET_API_KEY"] as? String else {
            fatalError("Missing PLANTNET_API_KEY in Config.plist")
        }
        return key
    }()

    func identifyPlant(image: UIImage, organ: String = "auto") async throws -> PlantIdentificationResult {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PlantNetError.invalidImage
        }

        let boundary = UUID().uuidString
        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "include-related-images", value: "false"),
            URLQueryItem(name: "no-reject", value: "false"),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"images\"; filename=\"plant.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add organ type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"organs\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(organ)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PlantNetError.networkError("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw PlantNetError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
            }

            let decoder = JSONDecoder()
            return try decoder.decode(PlantIdentificationResult.self, from: data)
        } catch let error as PlantNetError {
            throw error
        } catch let error as DecodingError {
            throw PlantNetError.decodingError(error.localizedDescription)
        } catch {
            throw PlantNetError.networkError(error.localizedDescription)
        }
    }
}
