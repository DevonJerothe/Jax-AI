// {
//   "max_context_length": 2048,
//   "max_length": 100,
//   "prompt": "Niko the kobold stalked carefully down the alley, his small scaly figure obscured by a dusky cloak that fluttered lightly in the cold winter breeze.",
//   "quiet": false,
//   "rep_pen": 1.1,
//   "rep_pen_range": 256,
//   "rep_pen_slope": 1,
//   "temperature": 0.5,
//   "tfs": 1,
//   "top_a": 0,
//   "top_k": 100,
//   "top_p": 0.9,
//   "typical": 1
// }

import Foundation

public class PromptModel: Codable {
    public var maxContextLength: Int?
    public var maxLength: Int?
    public var prompt: String?
    public var quiet: Bool?
    public var repPen: Double?
    public var repPenRange: Int?
    public var repPenSlope: Double?
    public var temperature: Double?
    public var tfs: Int?
    public var topA: Int?
    public var topK: Int?
    public var topP: Double?
    public var typical: Int?
    public var memory: String?
    public var stopSequence: [String]?
    public var trimStop: Bool?
    public var samplerOrder: [Int]?

    public init(
        maxContextLength: Int = 4096,
        maxLength: Int = 240,
        prompt: String,
        quiet: Bool = false,
        repPen: Double = 1.07,
        repPenRange: Int = 360,
        repPenSlope: Double = 0.7,
        temperature: Double = 0.75,
        tfs: Int = 1,
        topA: Int = 0,
        topK: Int = 100,
        topP: Double = 0.92,
        typical: Int = 1,
        memory: String? = nil,
        stopSequence: [String] = ["\nUser:", "\nBot:"],
        trimStop: Bool = true,
        samplerOrder: [Int] = [6, 0, 1, 3, 4, 2, 5],
        promptTemplate: String? = nil
    ) {
        self.maxContextLength = maxContextLength
        self.maxLength = maxLength
        self.prompt = prompt
        self.quiet = quiet
        self.repPen = repPen
        self.repPenRange = repPenRange
        self.repPenSlope = repPenSlope
        self.temperature = temperature
        self.tfs = tfs
        self.topA = topA
        self.topK = topK
        self.topP = topP
        self.typical = typical
        self.stopSequence = stopSequence
        self.trimStop = trimStop
        self.samplerOrder = samplerOrder

        if var promptTemplate = promptTemplate {
            promptTemplate.append(memory ?? "")
            self.memory = promptTemplate
        } else {
            self.memory = memory
        }
    }
}

// TODO: Fix the force unwrapping here. We should handle any errors gracefully
extension PromptModel {
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let requestData = try! encoder.encode(self)
        return String(data: requestData, encoding: .utf8)!
    }
}
