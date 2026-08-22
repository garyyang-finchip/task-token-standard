# Task Token as a Reverse Asset — Reference Implementation

Reference implementation, deterministic toolchain, and test vectors for the ERC draft
**"Token-Bound Task Tenders"** (TASK-KERNEL v3.0).

An ERC-721 extension that binds a token to a hash-verifiable task tender: the chain
anchors *exactly which task specification, acceptance criteria, version, and publication
history* a token commits to — together with an escrowed reward paid per accepted
completion. It is the demand-side inverse of
[Token-Bound Executable Skills](https://github.com/garyyang-finchip/skill-token-standard)
(ERC-8338): where a skill token wraps supplied value awaiting payment, a task token
wraps committed payment awaiting supplied value.

```
Supply side (ERC-8338):   T(f(v), $)      = ($, v)   the seller moves first
Demand side (this work):  T(v, f⁻¹($))    = ($, v)   the buyer moves first
Together:                 T(f(v), f⁻¹($)) = ($, v)   the agent economy, bidirectionally complete
```

The wrapping is literal: every task token deploys a **per-token locked vault** at mint —
the bounty sits at the token's own vault address, visible to any explorer, spendable by
no one, released only through settlement or refund. The vault is the tender's credit
foundation and travels with the NFT through every trade.

```
ERC-721 layer          who owns this task token (a funded tender is a tradable demand-side asset)
Task Binding layer     tdHash / taskHash / version / taskURI / updateAuthority / frozen
Tender layer           per-token locked VAULT / immutable terms (asset, reward, maxCompletions,
                       submitBy, settleBy, epochLength, maxCompletionsPerEpoch) /
                       acceptance authority spectrum: verifier contract => machine settlement
                       (permissionless, "solve it and the vault pays") · any judging address =>
                       judged settlement / submissions / refund
On-chain Document      optional plaintext primary task document, readable from the chain itself
Task Object Model      deterministic DAG-CBOR object graph, per-file CIDs (off-chain, normative),
                       byte-compatible with the ERC-8338 Skill Object Model — one toolchain, two standards
```

## Fulfillment shapes (one number + one address, no new mechanisms)

| Shape | On-chain expression |
|---|---|
| Exclusive — one task, one fulfiller | `maxCompletions = 1` |
| Collaborative — one task, a team shares one reward | `maxCompletions = 1`, fulfiller of record = split contract (ERC-1155 shares) |
| Replicated — N completions, each earns the same reward | `maxCompletions = N` (0 = unbounded, funded incrementally) |
| Standing (subscription-reverse) — paced deliveries over time | `epochLength` + `maxCompletionsPerEpoch` (e.g. 1/day × 365) — the inverse of supply-side metered point-card assets |
| Subcontracted | submission permissionless; economic shares transfer via companion ERC-1155 contracts |

Settlement spans the whole task spectrum through one slot: point `acceptanceAuthority`
at a verifier contract (`ITaskVerifier` via ERC-165) and the task is **machine-settled** —
anyone may call `settleFulfillment` with a proof, so fully quantifiable tasks (solve an
equation, reveal a preimage, oracle-confirmed outcomes) pay with no one in the loop.
Point it at any judging address — an EOA at cold start, the `JuryPanel` K-of-N reference,
a DAO later — and the task is **judged**; governance evolves by one
`setAcceptanceAuthority` call, never by touching the standard.

The contract enforces arithmetic (counting, solvency, deadlines, authority); the
acceptance authority enforces semantics (eligibility, quality, team composition) per the
fulfillment descriptor committed inside `taskHash`.

## Repository layout

```
ERCS/erc-9999.md         the ERC draft (placeholder number, assigned by editors at PR time)
contracts/               TaskToken.sol + TaskVault.sol + interfaces (ITaskToken / ITaskTender
                         / ITaskVerifier / IOnchainTaskDocument)
contracts/verifiers/     HashlockVerifier.sol — stock machine-settlement verifier
contracts/judgment/      JuryPanel.sol — K-of-N reference judging authority
test/                    Foundry suite, one assertion cluster per MUST clause
tools/task-pack/         pack.py (canonical packer) / verify.py (fulfiller-side verifier)
                         / tom.py (deterministic DAG-CBOR + CID library, zero deps)
schemas/                 task manifest + fulfillment descriptor + confidentiality JSON Schemas
vectors/                 frozen test vectors (KEY.demo files are NON-CRYPTOGRAPHIC TEST keys)
sample-task/             the source package the vectors are built from
scripts/                 local_e2e.sh + smoke.mjs (solc-js + ganache lifecycle, 55 assertions)
vectors-objects-bundle.tar.gz   insurance copy of all vectors/*/objects/
```

Interface IDs (compiler-verified, solc 0.8.24):
`ITaskToken = 0xcdaeb26d` · `ITaskTender = 0xfced0e08` · `ITaskVerifier = 0x9977db15` · `IOnchainTaskDocument = 0xeb078d05`

## Quick start

```bash
# 0) clone fresh
git clone https://github.com/garyyang-finchip/task-token-standard.git
cd task-token-standard

# 1) hygiene: strip CRLF (Windows transit) and restore objects if transport dropped them
find . \( -name '*.sh' -o -name '*.py' \) -exec sed -i 's/\r$//' {} +
ls vectors/public-v1/objects >/dev/null 2>&1 || tar -xzf vectors-objects-bundle.tar.gz

# 2) offline verification (no chain needed) — proves the deterministic toolchain
TD=$(python3 -c "import json;print(json.load(open('vectors/public-v1/vector.json'))['tdHash'])")
TH=$(python3 -c "import json;print(json.load(open('vectors/public-v1/vector.json'))['taskHash'])")
python3 tools/task-pack/verify.py vectors/public-v1 --tdhash $TD --taskhash $TH --max-completions 10
# expected: [OK] steps ... PASS - task package verified; safe to price, fulfill, and cite this version.

# 3) Foundry: compile + full MUST-clause test suite
curl -L https://foundry.paradigm.xyz | bash && source ~/.bashrc && foundryup
forge install foundry-rs/forge-std --no-git
forge build
forge test -vvv

# 4) local chain lifecycle without Foundry (solc-js + ganache + ethers):
#    vault lock -> judged + machine settlement -> epoch pacing -> jury panel ->
#    cancel -> pro-rata reclaim + owner residual -> on-chain document. 55 assertions.
npm install -g solc@0.8.24 ganache && npm install ethers@6
bash scripts/local_e2e.sh
# expected: SMOKE RESULT: 55 passed, 0 failed

```

## Status — Milestone M3 (2026-08-22, TASK-KERNEL v3.0)

**v3.0 closes the free-look asymmetry of the demand side.** A supply-side artifact is
bought against a hash and can be checked after payment; a task fulfiller has to reveal
the work *before* being paid, to the very party holding the money. v2.0 let that party
read a delivery and then cancel, or stall, and reclaim the bounty — an attack we
reproduced end to end before fixing it. Three rules remove it, using counting and a
clock rather than cryptography:

- **A delivery reserves a slot and a reward.** `submitFulfillment` reverts unless the
  tender has an unreserved slot and the vault can cover every Pending reward at once.
  `pendingOf` and `lockedEscrowOf` expose the reservation; refunds cannot touch it.
- **Cancellation stops new work, not delivered work.** Submissions Pending at
  cancellation stay acceptable, rejectable, settleable, and claimable; `reclaimEscrow`
  and `reclaimResidual` revert while anything is still Pending.
- **Silence pays the fulfiller.** `claimUnjudged` is permissionless: past
  `submittedAt + judgmentWindow`, an unjudged delivery settles to its fulfiller, and
  it ignores both cancellation and `settleBy`. On the machine path it is refused —
  there, code already ruled. Rejecting is still allowed, but it must be said out loud,
  on-chain, inside a window published before any work began.
- **And junk cannot squat a machine tender.** `releaseExpired` is the machine-path
  counterpart: past the same deadline, a submission that never produced a valid proof
  is released by anyone, freeing its slot and reward. Without it the reservation rule
  would be a weapon — with no judge to reject junk, filling every slot would freeze
  the vault forever.

`Submission` gains `submittedAt`, so a verifier profile can also require a minimum
submission age against mempool front-running. `TenderTerms` gains `judgmentWindow`.

- Deterministic toolchain closed end-to-end: three frozen vectors (`public-v1`,
  `update-v2-companion-only` with constant `tdHash`, `confidential-v1`) pack, verify,
  and fail correctly on tampered inputs (descriptor/chain mismatch, missing key)
- Contracts compile clean under solc 0.8.24 (optimized, zero warnings). `TaskToken`
  deployed runtime code is 22,836 bytes — under the EIP-170 limit of 24,576
  (creation bytecode 23,585); `TaskVault` 839, `JuryPanel` 2,812,
  `HashlockVerifier` 1,665. All four interface IDs compiler-verified
- Full v3 lifecycle proven on a local chain: **74/74 assertions PASS**
  (`scripts/local_e2e.sh`), covering the locked per-token vault (visible balance,
  drain attempts revert, direct-transfer gifts count as escrow), judged settlement
  paying from the vault, permissionless machine settlement via HashlockVerifier
  (wrong proofs leave submissions Pending; copied commitments cannot steal payouts;
  set-once answers), epoch pacing (1/day standing tender across a day boundary),
  JuryPanel 2-of-3 quorum settlement plus timeout-default rejection, terminal
  rejection, completion bounds, cancellation, pro-rata refunds over the attributed
  pool only, the gift-residual rule, and every free-look route: slot and reward
  reservation, sock-puppet slot starvation, refund and residual locks while work is
  Pending, the judgment deadline, its refusal on machine-settled tenders, and the
  machine-path release that stops junk submissions freezing a vault

## Worked examples

`examples/` carries end-to-end commercial cases, each a real task package whose
on-chain anchors are re-derivable from this repository:

```
examples/case-1-labeling-qa/          support-ticket intent labeling settled per batch
                                      against gold-standard QA receipts
examples/verifiers/                   verifier contracts used by the examples;
BatchReceiptVerifier.sol              profile x-batch-receipt-merkle-minage-v1 —
                                      one secret per claim (Merkle root over
                                      sha256(receipt || assigned fulfiller)) plus a
                                      minimum submission age read from `submittedAt`
```

Re-derive an example's anchors the same way as the frozen vectors:

```bash
python3 tools/task-pack/pack.py examples/case-1-labeling-qa --out examples/case-1-labeling-qa/out     --primary TASK.md --spec spec/labeling-schema.yaml --spec-profile x-support-intent-taxonomy-v1     --acceptance acceptance/gold-standard-qa.md --acceptance-profile x-batch-receipt-merkle-minage-v1     --max-completions 3
```

## Reproducing the vectors

Two independent implementations MUST reproduce `vectors/*/taskroot.cbor` byte-for-byte.

```bash
python3 tools/task-pack/pack.py <task-dir> --out out/ \
    [--primary TASK.md] [--spec spec/api.yaml] \
    [--acceptance acceptance/harness.py --acceptance-profile x-pytest-v1] \
    [--max-completions N] \
    [--version N --prev 0x<previous-taskHash>] \
    [--encrypt path1,path2 --key <hex>]
python3 tools/task-pack/verify.py out/ --tdhash 0x.. --taskhash 0x.. \
    [--version N --previous-taskhash 0x..] [--max-completions N] [--key <hex>]
```

The verifier enforces: taskHash, canonical re-encode byte-equality, closed-map schema +
path rules, spec/acceptance interlocks, the version chain (`digest(prev) == previous
taskHash`), confidentiality descriptor cross-matching against TaskRoot links, per-leaf
digests, plaintext `tdHash`, strict UTF-8 on the primary document, and descriptor/chain
agreement on `maxCompletions`.

## Relationship to ERC-8338

The Task Object Model (tom.py) is byte-compatible with the Skill Object Model (som.py):
identical deterministic DAG-CBOR encoding, identical CID/link form, identical path rules,
identical confidentiality descriptor. A deliverable that is itself an ERC-8338 skill
package settles a task by pointing `resultHash` at that package's `packageHash` — the
reverse asset retires into a forward asset, and the trade `T(f(v), f⁻¹($)) = ($, v)`
clears entirely on-chain.

## License

Specification and reference code released under [CC0](LICENSE).
`x-test-sha256-xor-stream-v1` is a NON-CRYPTOGRAPHIC TEST profile — never use it in production.
