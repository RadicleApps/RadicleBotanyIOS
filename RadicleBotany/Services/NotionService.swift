import Foundation

enum NotionError: LocalizedError {
    case invalidToken
    case invalidPageID
    case networkError(String)
    case apiError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Notion integration token is missing or invalid."
        case .invalidPageID:
            return "Notion parent page ID is missing or invalid."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "Notion API error: \(message)"
        case .decodingError(let message):
            return "Failed to parse Notion response: \(message)"
        }
    }
}

class NotionService {
    static let shared = NotionService()

    private let baseURL = "https://api.notion.com/v1"
    private let notionVersion = "2022-06-28"

    // MARK: - Export Note

    /// Creates a new page in the user's Notion workspace with the note content.
    /// Returns the URL of the created Notion page.
    func exportNote(
        _ note: JournalNote,
        token: String,
        parentPageID: String
    ) async throws -> String {
        guard !token.isEmpty else { throw NotionError.invalidToken }
        guard !parentPageID.isEmpty else { throw NotionError.invalidPageID }

        let url = URL(string: "\(baseURL)/pages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build page title
        let title = note.title.isEmpty ? "Untitled Note" : note.title

        // Build content blocks
        var children: [[String: Any]] = []

        // Note content as paragraph blocks (split by newlines for better formatting)
        let paragraphs = note.content.components(separatedBy: "\n\n")
        for paragraph in paragraphs where !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            children.append([
                "object": "block",
                "type": "paragraph",
                "paragraph": [
                    "rich_text": [
                        ["type": "text", "text": ["content": String(paragraph.prefix(2000))]]
                    ]
                ]
            ])
        }

        // Add metadata block
        var metaLines: [String] = []
        let dateString = note.date.formatted(date: .long, time: .shortened)
        metaLines.append("Date: \(dateString)")

        if let entityType = note.entityType, let entityID = note.linkedEntityID {
            metaLines.append("Linked \(entityType.displayName): \(entityID)")
        }

        children.append([
            "object": "block",
            "type": "divider",
            "divider": [:] as [String: String]
        ])

        children.append([
            "object": "block",
            "type": "paragraph",
            "paragraph": [
                "rich_text": [
                    [
                        "type": "text",
                        "text": ["content": metaLines.joined(separator: " · ")],
                        "annotations": ["italic": true, "color": "gray"]
                    ]
                ]
            ]
        ])

        // Build the full payload
        let payload: [String: Any] = [
            "parent": ["page_id": parentPageID],
            "properties": [
                "title": [
                    "title": [
                        ["text": ["content": title]]
                    ]
                ]
            ],
            "children": children
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NotionError.networkError("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[NotionService] ❌ API error (\(httpResponse.statusCode)): \(errorBody)")
                throw NotionError.apiError("Status \(httpResponse.statusCode)")
            }

            // Extract page URL from response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pageURL = json["url"] as? String {
                print("[NotionService] ✅ Created page: \(pageURL)")
                return pageURL
            }

            print("[NotionService] ✅ Page created (no URL in response)")
            return "success"
        } catch let error as NotionError {
            throw error
        } catch {
            throw NotionError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Test Connection

    /// Tests whether the token is valid by fetching the bot user info.
    func testConnection(token: String) async throws -> String {
        guard !token.isEmpty else { throw NotionError.invalidToken }

        let url = URL(string: "\(baseURL)/users/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NotionError.networkError("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                throw NotionError.apiError("Token invalid or expired (status \(httpResponse.statusCode))")
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = json["name"] as? String {
                return name
            }

            return "Connected"
        } catch let error as NotionError {
            throw error
        } catch {
            throw NotionError.networkError(error.localizedDescription)
        }
    }
}
