#!/usr/bin/env bash
# Canonical pack commands for every example package. These are the exact flags the
# Sepolia record in examples/DEPLOYMENTS.md was produced with: run this and every
# tdHash / taskHash / resultHash in that file re-derives byte for byte.
# Run from the repository root; writes examples/*/out/.
set -e
P="python tools/task-pack/pack.py"
KEY=$(tr -d '\r\n ' < examples/case-4-KEY.demo | sed 's/^0x//')
rm -rf examples/*/out

$P examples/case-1-labeling-qa --out examples/case-1-labeling-qa/out \
   --primary TASK.md --spec spec/labeling-schema.yaml --spec-profile x-support-intent-taxonomy-v1 \
   --acceptance acceptance/gold-standard-qa.md --acceptance-profile x-batch-receipt-merkle-minage-v1 \
   --max-completions 3 >/dev/null

$P examples/case-2-media-sla --out examples/case-2-media-sla/out \
   --primary TASK.md --spec spec/daily-report-schema.yaml --spec-profile x-daily-media-report-v1 \
   --acceptance acceptance/review-checklist.md --acceptance-profile x-human-review-checklist-v1 \
   --max-completions 5 >/dev/null

$P examples/case-3-invoice-agent --out examples/case-3-invoice-agent/out \
   --primary TASK.md --spec spec/agent-interface.yaml --spec-profile x-invoice-extraction-agent-v1 \
   --acceptance acceptance/evaluation-protocol.md --acceptance-profile x-heldout-scored-eval-v1 \
   --max-completions 1 >/dev/null

for v in v1 v2; do
$P examples/case-3-deliverable-$v --out examples/case-3-deliverable-$v/out \
   --primary SKILL.md --spec spec/runtime.yaml --spec-profile x-invoice-extraction-agent-v1 \
   --max-completions 1 >/dev/null
done

$P examples/case-4-tax-opinion-v1 --out examples/case-4-tax-opinion-v1/out \
   --primary TASK.md --spec spec/engagement-scope.yaml --spec-profile x-tax-opinion-engagement-v1 \
   --acceptance acceptance/opinion-standard.md --acceptance-profile x-tax-opinion-conformance-v1 \
   --max-completions 1 --encrypt spec/engagement-scope.yaml --key $KEY >/dev/null
V1=$(python -c "import json;print(json.load(open('examples/case-4-tax-opinion-v1/out/vector.json'))['taskHash'])")

$P examples/case-4-tax-opinion --out examples/case-4-tax-opinion/out \
   --primary TASK.md --spec spec/engagement-scope.yaml --spec-profile x-tax-opinion-engagement-v1 \
   --acceptance acceptance/opinion-standard.md --acceptance-profile x-tax-opinion-conformance-v1 \
   --max-completions 1 --encrypt spec/engagement-scope.yaml --key $KEY --version 2 --prev $V1 >/dev/null

$P examples/case-4-deliverable --out examples/case-4-deliverable/out \
   --primary OPINION.md --spec spec/delivery-declaration.yaml --spec-profile x-signed-opinion-package-v1 \
   --max-completions 1 >/dev/null

$P examples/case-5-benchmark-consortium --out examples/case-5-benchmark-consortium/out \
   --primary TASK.md --spec spec/benchmark-release.yaml --spec-profile x-financial-text-benchmark-v1 \
   --acceptance acceptance/committee-review.md --acceptance-profile x-committee-vote-v1 \
   --max-completions 2 >/dev/null

echo "packed: $(ls -d examples/*/out | wc -l) packages"
