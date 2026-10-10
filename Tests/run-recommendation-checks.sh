#!/bin/zsh
set -eu
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/choosemyllm-checks.XXXXXX")"
trap 'rm -rf "$scratch_dir"' EXIT
xcrun --sdk macosx swiftc \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$scratch_dir/ModuleCache" \
    "$project_dir/ChooseMyLLM/UserRequirements.swift" \
    "$project_dir/ChooseMyLLM/HuggingFaceClient.swift" \
    "$project_dir/ChooseMyLLM/ModelRecommendations.swift" \
    "$project_dir/Tests/RecommendationChecks.swift" \
    -o "$scratch_dir/checks"
"$scratch_dir/checks" "$project_dir/ChooseMyLLM/recommendation-catalog.json"
