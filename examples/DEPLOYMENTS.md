# Sepolia reference deployment

Every worked example in `examples/` was executed end to end on Sepolia against a
single deployment of the reference implementation. Nothing below is simulated: each
row is a token that was minted, funded, delivered against, judged, and settled or
refunded on a public chain, and every hash in this file is re-derivable from this
repository with `tools/task-pack/pack.py`.

This deployment is the implementation as it stands in `contracts/` after three rounds
of external review (v3.2.1). It supersedes the pre-review deployment at
`0x0c94CbEf5BC8493c6c0fFe086c090a86bB787415`, which is kept on chain as a record but
MUST NOT be cited as the reference.

**Network:** Sepolia (chain id 11155111)
**Kernel:** TASK-KERNEL v3.2.1
**Compiler:** solc 0.8.24, optimizer enabled, 1 run
**Deployed runtime:** 23,766 bytes (EIP-170 limit 24,576)
**Executed:** 2026-09-05, 107 on-chain assertions across the five examples, zero failures

## Contracts

| Contract | Address | Role |
| --- | --- | --- |
| `TaskToken` | `0xA62059A498E40C4Ae4aF926E2B00C1Ff122bDdb7` | the reference implementation; every example token lives here |
| `HashlockVerifier` | `0x495270468A4608e4c84968b1037ef7eceBF5d3ec` | stock machine-settlement verifier (`contracts/verifiers/`) |
| `BatchReceiptVerifier` | `0x075CF6D7236e50Bb120f3285035f51E0321B30EA` | example verifier: one secret per claim plus a minimum submission age |
| `JuryPanel` | `0x7249E48c7E2131ADA0fcc25b1eaE4f4258545511` | 2-of-2 review committee, 60-second voting window |
| `FixedSplitter` | `0xEcb83C71fc1692Dc9ED65dD3f46BAA803bBdE8a2` | a team as fulfiller of record, shares 50/30/20 |
| `DemoUSD` | `0x2c36C7c918e3244aBd70b405952EB4c2FB8A8d05` | points-style ERC-20 used to price case 4; **not a stablecoin** |

ERC-165 interface identifiers, compiler-verified and reported on-chain:
`ITaskToken = 0xcdaeb26d` · `ITaskTender = 0xc319d532` ·
`ITaskVerifier = 0x9977db15` · `IOnchainTaskDocument = 0xeb078d05`

## Tokens

| # | Example | Judgment | Asset | Outcome |
| --- | --- | --- | --- | --- |
| 1 | reference mint from `vectors/public-v1` | judged (N=1) | native | frozen and funded; left open as a live reference tender |
| 2 | `case-2-media-sla` | judged (N=1) | native | 4 periods paid, 1 refunded, cancelled, vault zero |
| 3 | `case-3-invoice-agent` | judged (N=1) | native | revision 1 rejected, revision 2 accepted, exclusive award spent |
| 4 | `case-3-invoice-agent` (deadline tender) | judged (N=1) | native | delivered in time, buyer ran out the clock, fulfiller claimed by default |
| 5 | `case-4-tax-opinion` | judged (N=1) | **DemoUSD** | scope revised v1→v2 before freezing, opinion delivered and accepted |
| 6 | `case-5-benchmark-consortium` | **committee (2-of-2)** | native | release 1 accepted at quorum and split 50/30/20; release 2 rejected on committee timeout |
| 7 | `case-1-labeling-qa` | **machine (N=0)** | native | 3 of 3 batches settled with no judge in the loop |

## Per-token detail

| # | vault | `tdHash` | `taskHash` |
| --- | --- | --- | --- |
| 1 | `0x62B63071b6505887ACb4b9AAd56459D1dEF950E3` | `0x6ad6b032…bef51` | `0x4c26ef3d…543f0` |
| 2 | `0xCa440D770c02A6536feeFa410E27583f2F90D3D1` | `0x15e36f9d…3ed15` | `0x334112fb…4ef71` |
| 3 | `0x473F994A3c74d6e3E245430F9450A1B2179352fb` | `0xcf05fd60…856f6` | `0x5ee9f031…1628f` |
| 4 | `0x40aF04eF8AAe7D5da2300f16FD6162c2a6A0776E` | `0xcf05fd60…856f6` | `0x5ee9f031…1628f` |
| 5 | `0xA933Ab14982023940Df7E64537aFc4C2b6F591b7` | `0x1dcff919…eb387` (constant across both revisions) | v1 0x5385e8cd…49a5c → v2 0xc349895e…e400f |
| 6 | `0xfD188aD10E6E1be6717962cad5d524C5BDb935fB` | `0x9288202a…c74fd` | `0xdcc3850c…4ebc2` |
| 7 | `0xC13F993C6b0d5300aE648db15A0Ac36caB9E64D3` | `0x8051df89…d49f4` | `0x4f3ef8bd…04788` |

Deliverable commitments settled on-chain, also re-derivable from this repository:

| Example | `resultHash` | Source |
| --- | --- | --- |
| case 3, rejected | `0x3f181e662c01b95d6b308cc4e0a5b33aa7ffa2cf981a36ad9a1169aa62c0d92a` | `examples/case-3-deliverable-v1/` |
| case 3, accepted | `0x37bd848ed937ed319857f247d18d343767b6597b43e167369d5ec91d6aa1200a` | `examples/case-3-deliverable-v2/` |
| case 4, accepted | `0x437cb3e9023a8795b464794d50d4743f9608768590719c9b1e2e0ace4e335d1e` | `examples/case-4-deliverable/` |

## What each example demonstrated

**Case 1 — machine settlement, no judge anywhere.** The judgment slot held a verifier
contract, so `acceptFulfillment` was closed even to the issuer and the committed
answer set was fixed before freezing. Three distinct annotators each settled their own
batch; a third party paid the gas for one settlement and the reward still went to the
recorded fulfiller. A revealed receipt was then replayed from another address and
failed twice — once on the minimum submission age, once, after the age requirement was
met, on the Merkle proof — because each claim's leaf binds the annotator it was issued
to. The junk left behind squatted the last slot until `releaseExpired` freed it.

**Case 2 — a faucet task token, paced.** One settlement per period, enforced against
both the judged path and the deadline path. Delivery was not paced; settlement was.
The buyer rejected one report on the record, the supplier corrected it, and when the
buyer went silent on a later period the supplier claimed the fee itself. Cancelling
mid-campaign did not void the report already delivered.

**Case 3 — an exclusive build with two deadlines.** A tender whose decision deadline
preceded its delivery deadline was refused at mint. Revision 1 was rejected with the
measured shortfall, revision 2 accepted; the rejected submission could never be
revived. On the second token, delivery after `submitBy` was refused, the buyer could
not settle after `settleBy`, could not reclaim while a delivery it had never ruled on
was pending, and the fulfiller was paid by default anyway.

**Case 4 — confidential, and priced in a stable unit.** The engagement scope was an
encrypted object; verification passes with the key and fails without it. The scope was
revised before freezing, so `tdHash` stayed constant while `taskHash` moved and the
contract incremented the version to 2 — and the delivery records that it answered
revision 2. Funding in a token rejected accompanying ether. The deliverable is a real
document, `examples/case-4-deliverable/OPINION.md`, which passes the tender's own
public conformance check (20 checks) and which that check rejects when deliberately
degraded.

**Case 5 — funders, judges and workers, all different parties.** Two institutions
funded the same vault with attribution, a third gifted it anonymously. A 2-of-2
committee held judgment: the poster's vote was refused, one approval moved nothing,
the second settled in the same transaction. The reward went to a split contract and
was distributed 50/30/20, with two members paid without ever sending a transaction.
On the second release the committee's timeout — deliberately shorter than
`judgmentWindow` — landed first, so the delivery was rejected rather than claimed.
Both named funders were then refunded in full because the anonymous gift had absorbed
the reward, and the unspent gift went to the token holder.

## Reproducing any of it

```bash
# 1. re-derive every example's anchors from source (all nine packages, canonical flags)
bash scripts/pack_examples.sh

#    or one at a time, e.g.
python3 tools/task-pack/pack.py examples/case-1-labeling-qa --out out/ \
    --primary TASK.md --spec spec/labeling-schema.yaml --spec-profile x-support-intent-taxonomy-v1 \
    --acceptance acceptance/gold-standard-qa.md --acceptance-profile x-batch-receipt-merkle-minage-v1 \
    --max-completions 3

# 2. compare against the chain
cast call 0xA62059A498E40C4Ae4aF926E2B00C1Ff122bDdb7 "taskOf(uint256)" 7 --rpc-url $SEPOLIA_RPC
```

The on-chain primary document can be read back with `taskDocument(tokenId)` and
hashed: it equals `tdHash` for every token that published one.

## Provenance and honesty notes

- These tokens were produced on the implementation as reviewed. Fourteen defects were
  found and fixed before this deployment — three by building these examples, eleven
  across three rounds of external review — and every one is covered by a test that
  fails against the code that had it. The earlier deployment at
  `0x0c94CbEf5BC8493c6c0fFe086c090a86bB787415` predates the last eleven.
- A first v3.2.1 deployment at `0x1B3EC29e538D1614FE260216c2cb0D495a3bFE8A` was abandoned
  the same day: its example packages had been packed with abbreviated flags, so the
  `taskHash` values minted there are not the ones `scripts/pack_examples.sh`
  derives. The contract is correct; its tokens 2–6 are simply not reproducible from
  this repository and MUST NOT be cited. The deployment above is the reference.
- The *work* behind each example is illustrative. Nobody labelled 30,000 tickets or
  built an invoice agent. What is real is the protocol: every commitment, judgment,
  payment, refund and refusal above happened on Sepolia, and every hash is checkable
  against this repository. Case 4 is the exception in one respect — its deliverable is
  a genuine document that passes a genuine automated check.
- `DemoUSD` is play money with an open faucet and no redemption. It exists so the
  examples can price work in a unit that does not move against the work.
- All parties, figures and facts inside the example task and deliverable documents are
  fictional.
