import Foundation

/// Owner Backend Configuration — Universal intelligence backend for all users.
///
/// The app owner's OpenAI API key powers intelligent features for everyone.
/// This eliminates the "configure API key" dead end — every user gets enhanced responses.
///
/// Security approach:
/// - Development/TestFlight: XOR-obfuscated key in app bundle
/// - Production: Replace with proxy server URL (Cloudflare Worker / Vercel Edge)

struct OwnerBackendConfig {

    // MARK: - Configuration

    /// Whether the owner backend is available
    static var isAvailable: Bool {
        return deobfuscateKey() != nil
    }

    /// Retrieve the owner's OpenAI API key
    static func getAPIKey() -> String? {
        return deobfuscateKey()
    }

    /// API provider
    static let provider = "openai"

    /// Model to use for owner-funded requests
    static let model = "gpt-4o-mini"

    /// Max tokens for owner-funded responses (includes [SOURCES] block overhead)
    static let maxTokens = 768

    /// Request timeout in seconds
    static let requestTimeout: TimeInterval = 15

    // MARK: - Obfuscated Key Storage

    /// XOR key for basic obfuscation — NOT encryption, just deters casual extraction.
    /// For production, replace this entire mechanism with a proxy server URL.
    private static let xorKey: [UInt8] = [
        0x52, 0x42, 0x6F, 0x74, 0x61, 0x6E, 0x79, 0x41,
        0x70, 0x70, 0x32, 0x30, 0x32, 0x36, 0x4B, 0x65
    ]

    /// The obfuscated API key bytes (OpenAI key, XOR'd against xorKey).
    private static let obfuscatedKeyBytes: [UInt8] = [
        0x21, 0x29, 0x42, 0x04, 0x13, 0x01, 0x13, 0x6C, 0x43, 0x24, 0x55, 0x65, 0x76, 0x5B, 0x14, 0x30,
        0x1E, 0x05, 0x05, 0x16, 0x07, 0x31, 0x28, 0x6C, 0x0A, 0x43, 0x6D, 0x63, 0x66, 0x72, 0x22, 0x21,
        0x21, 0x27, 0x5C, 0x24, 0x37, 0x25, 0x37, 0x32, 0x18, 0x41, 0x58, 0x66, 0x68, 0x67, 0x00, 0x3A,
        0x25, 0x2F, 0x35, 0x13, 0x28, 0x39, 0x14, 0x12, 0x33, 0x31, 0x0B, 0x4A, 0x5E, 0x72, 0x0F, 0x0F,
        0x14, 0x36, 0x1E, 0x22, 0x39, 0x02, 0x1C, 0x33, 0x14, 0x31, 0x65, 0x63, 0x65, 0x62, 0x0E, 0x54,
        0x3F, 0x2C, 0x3B, 0x47, 0x23, 0x02, 0x1B, 0x2A, 0x36, 0x3A, 0x57, 0x02, 0x65, 0x4F, 0x05, 0x21,
        0x62, 0x05, 0x25, 0x3F, 0x0C, 0x3C, 0x4F, 0x03, 0x20, 0x2A, 0x4B, 0x08, 0x58, 0x57, 0x2C, 0x55,
        0x15, 0x13, 0x09, 0x15, 0x0F, 0x28, 0x4B, 0x02, 0x1E, 0x01, 0x0B, 0x6F, 0x47, 0x7F, 0x08, 0x53,
        0x67, 0x0E, 0x58, 0x01, 0x0D, 0x3D, 0x2B, 0x70, 0x1D, 0x47, 0x57, 0x7F, 0x7D, 0x50, 0x0A, 0x51,
        0x04, 0x13, 0x38, 0x00, 0x03, 0x07, 0x01, 0x27, 0x38, 0x33, 0x42, 0x5B, 0x65, 0x5C, 0x2C, 0x03,
        0x3D, 0x10, 0x26, 0x35
    ]

    /// Deobfuscate the stored key
    private static func deobfuscateKey() -> String? {
        guard !obfuscatedKeyBytes.isEmpty else { return nil }

        var result: [UInt8] = []
        for (i, byte) in obfuscatedKeyBytes.enumerated() {
            result.append(byte ^ xorKey[i % xorKey.count])
        }

        guard let key = String(bytes: result, encoding: .utf8),
              key.hasPrefix("sk-proj-") || key.hasPrefix("sk-ant-") else {
            return nil
        }

        return key
    }

    // MARK: - Key Obfuscation Utility

    /// Utility to obfuscate a plaintext API key for embedding.
    /// Call this once from a debug build to generate the bytes, then paste into `obfuscatedKeyBytes`.
    /// Usage: `print(OwnerBackendConfig.obfuscateKey("sk-ant-api03-..."))`
    static func obfuscateKey(_ plaintext: String) -> String {
        let bytes = Array(plaintext.utf8)
        var obfuscated: [UInt8] = []

        for (i, byte) in bytes.enumerated() {
            obfuscated.append(byte ^ xorKey[i % xorKey.count])
        }

        let hexParts = obfuscated.map { String(format: "0x%02X", $0) }
        return "[\(hexParts.joined(separator: ", "))]"
    }

    // MARK: - System Prompt

    /// System prompt for owner-backend requests — botanical focus, concise responses, sourced
    static let systemPrompt = """
    You are a botanical assistant for RadicleBotany. Your purpose is to help people learn about plants, identify species, and understand botanical terminology.

    Guidelines:
    - Be direct, accurate, and educational
    - Focus on plant morphology, taxonomy, ecology, and identification
    - Reference specific species, families, and botanical terms when relevant
    - Provide growing conditions and habitat information when asked
    - Keep responses concise (under 200 words for quick queries)
    - Use proper botanical nomenclature (italicized binomials)
    - When discussing conservation: reference IUCN status and geographic ranges
    - When discussing identification: emphasize key diagnostic features

    IMPORTANT — Citation requirement:
    After your response, add a [SOURCES] block listing every species, family, term, or resource you referenced. Format each source on its own line with a type prefix:
    [SOURCES]
    - Species: Quercus alba (White Oak)
    - Family: Fagaceae (Beech family)
    - Term: Pinnate venation
    - Source: Flora of North America
    Only include sources you actually cited in your response. Omit the [SOURCES] block if no sources apply.
    """
}
