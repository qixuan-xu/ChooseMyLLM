import Foundation

@main
struct RecommendationChecks {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        var catalog = try JSONDecoder().decode(RecommendationCatalog.self, from: data)
        var checks = 0
        func check(_ result: Bool, _ message: String) {
            precondition(result, message); checks += 1
        }
        var needs = UserRequirements()
        needs.macChip = .appleSilicon
        needs.memoryGB = 32
        needs.deployment = .local
        needs.useCase = .coding
        check(ModelRecommender.recommend(needs, catalog: catalog).picks.first?.id == "Qwen/Qwen2.5-Coder-7B-Instruct-GGUF", "Balanced coding should favor the coding profile")
        needs.useCase = .writing
        check(ModelRecommender.recommend(needs, catalog: catalog).picks.first?.id == "ggml-org/gemma-3-4b-it-GGUF", "Writing should affect the recommendation")
        needs.needsChinese = true
        check(ModelRecommender.recommend(needs, catalog: catalog).picks.allSatisfy { $0.profile.chineseFocused }, "Chinese preference must filter shortlist")
        needs.needsChinese = false
        needs.useCase = .everyday
        needs.priority = .speed
        let speed = ModelRecommender.recommend(needs,catalog:catalog).picks.first?.id
        needs.priority = .quality
        let quality = ModelRecommender.recommend(needs,catalog:catalog).picks.first?.id
        check(speed != quality, "Speed and quality should change the first recommendation")
        needs.memoryGB = 8
        let small = ModelRecommender.recommend(needs,catalog:catalog)
        check(small.picks.count == 1 && small.picks.first?.id == "unsloth/Qwen3.5-2B-GGUF", "8GB Mac should receive the lightweight candidate only")
        needs.memoryGB = 4
        check(ModelRecommender.recommend(needs,catalog:catalog).picks.isEmpty, "Do not recommend over-budget models")
        needs.memoryGB = 32
        needs.macChip = .intel
        check(ModelRecommender.recommend(needs,catalog:catalog).picks.isEmpty, "Do not imply Intel compatibility")
        needs.macChip = .appleSilicon
        needs.deployment = .cloud
        check(ModelRecommender.recommend(needs,catalog:catalog).picks.isEmpty, "Do not claim a free hosted tier without evidence")
        needs.mustBeFree = false
        check(ModelRecommender.recommend(needs,catalog:catalog).picks.count == 3, "Cloud should use active providers")
        let cloudID = "Qwen/Qwen3-32B"
        let previous = catalog.records[cloudID]!
        catalog.records[cloudID] = RecommendationRecord(model: RecommendationMetadata(id: cloudID, gated: .open, siblings: nil, inferenceProviderMapping: [:]), checkedAt: Date())
        check(!ModelRecommender.recommend(needs,catalog:catalog).picks.contains { $0.id == cloudID }, "No active provider must remove hosted candidate")
        catalog.records[cloudID] = previous
        needs.deployment = .local
        needs.mustBeFree = true
        let localID = "unsloth/Qwen3.5-2B-GGUF"
        let original = catalog.records[localID]!
        catalog.records[localID] = RecommendationRecord(model: RecommendationMetadata(id: localID, gated: .open, siblings: [], inferenceProviderMapping: nil), checkedAt: Date())
        check(!ModelRecommender.recommend(needs,catalog:catalog).picks.contains { $0.id == localID }, "Missing quantization files cannot pass memory checks")
        catalog.records[localID] = RecommendationRecord(model: original.model, checkedAt: Date(), unavailable: true)
        check(!ModelRecommender.recommend(needs,catalog:catalog).picks.contains { $0.id == localID }, "Unavailable repository must be removed")
        catalog.records[localID] = original
        for location in ModelDeployment.allCases {
            for memory in [4,8,16,24,32] {
                needs.deployment = location; needs.memoryGB = memory
                for priority in ModelPriority.allCases {
                    needs.priority = priority
                    let result = ModelRecommender.recommend(needs,catalog:catalog)
                    check(result.picks.count <= 3, "Keep results focused")
                    check(result.picks.allSatisfy { location == .either || $0.profile.location == location }, "Never change deployment silently")
                    check(result.picks.allSatisfy { $0.profile.freeToUse }, "Preserve free filter")
                    check(result.picks.allSatisfy { ($0.memoryGB ?? 0) <= memory }, "Preserve memory budget")
                }
            }
        }
        print("Passed \(checks) recommendation checks; automatic memory: \(UserRequirements().memoryGB) GB, chip: \(MacChip.detected.rawValue).")
    }
}
