// End-to-end lifecycle smoke test for TaskToken v3 (TASK-KERNEL v3.0) on a local chain.
// Covers: mint + genesis events -> per-token VAULT (visible, locked, gift deposits)
// -> freeze -> pooled funding -> judged settlement (pays from vault) -> terminal
// rejection -> maxCompletions bound -> machine settlement via HashlockVerifier
// (permissionless, front-run-bound commitments) -> epoch pacing (standing tender)
// -> JuryPanel K-of-N judged authority + timeout default -> cancel -> pro-rata
// reclaim incl. unattributed gifts -> on-chain document -> authority separation.
import { ethers } from "ethers";
import fs from "fs";

const OUT = (process.env.SOLC_OUT ?? "./solc-out") + "/";
const art = (n) => ({
  abi: JSON.parse(fs.readFileSync(OUT + n + ".abi")),
  bin: "0x" + fs.readFileSync(OUT + n + ".bin", "utf8").trim(),
});
const TT  = art("contracts_TaskToken_sol_TaskToken");
const TV  = art("contracts_TaskVault_sol_TaskVault");
const HLV = art("contracts_verifiers_HashlockVerifier_sol_HashlockVerifier");
const JP  = art("contracts_judgment_JuryPanel_sol_JuryPanel");

const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");
const wallets = [];
for (let i = 0; i < 10; i++) {
  wallets.push(ethers.HDNodeWallet.fromPhrase(
    "test test test test test test test test test test test junk",
    undefined, `m/44'/60'/0'/0/${i}`).connect(provider));
}
const managed = wallets.map(w => new ethers.NonceManager(w));
const [deployer, publisher, judge, funder, funder2, worker, rando, j1, j2, j3] = managed;
const A = (s) => s.signer.address;

const sha = (s) => ethers.sha256(typeof s === "string" ? ethers.toUtf8Bytes(s) : s);
const TD = sha("TASK.md v1"), TH = sha("taskroot v1"), TH2 = sha("taskroot v2");
let pass = 0, fail = 0;
const ok = (cond, msg) => { if (cond) { pass++; console.log("  [OK]", msg); } else { fail++; console.log("  [FAIL]", msg); } };
const mustRevert = async (thunk, msg) => { try { await thunk(); fail++; console.log("  [FAIL] (no revert)", msg); } catch { pass++; console.log("  [OK] reverts:", msg); } };
const warp = async (secs) => { await provider.send("evm_increaseTime", [secs]); await provider.send("evm_mine", []); };

const c = await new ethers.ContractFactory(TT.abi, TT.bin, deployer).deploy("Task Token", "TASK");
await c.waitForDeployment();
const hashlock = await new ethers.ContractFactory(HLV.abi, HLV.bin, deployer).deploy();
await hashlock.waitForDeployment();
const cAddr = await c.getAddress();
const hlAddr = await hashlock.getAddress();
console.log("TaskToken:", cAddr, " HashlockVerifier:", hlAddr);

// ERC-165 (compiler-verified ids)
ok(await c.supportsInterface("0xcdaeb26d"), "ERC-165 ITaskToken 0xcdaeb26d");
ok(await c.supportsInterface("0xfced0e08"), "ERC-165 ITaskTender 0xfced0e08");
ok(await c.supportsInterface("0xeb078d05"), "ERC-165 IOnchainTaskDocument 0xeb078d05");
ok(await hashlock.supportsInterface("0x9977db15"), "HashlockVerifier declares ITaskVerifier 0x9977db15");

// terms: (asset, rewardPerCompletion, maxCompletions, submitBy, settleBy, epochLength, maxPerEpoch)
const terms = { asset: ethers.ZeroAddress, rewardPerCompletion: ethers.parseEther("1"),
                maxCompletions: 2n, submitBy: 0n, settleBy: 0n, epochLength: 0n, maxCompletionsPerEpoch: 0n,
                judgmentWindow: 604800n };

// ---- token 1: judged lifecycle -------------------------------------------------
const rc = await (await c.mintTask(A(deployer), A(publisher), A(judge), TD, TH, "ipfs://task-v1", terms)).wait();
ok(rc.logs.length >= 4, `mint emits genesis event set (${rc.logs.length} logs)`);
const b = await c.taskOf(1);
ok(b.tdHash === TD && b.taskHash === TH && b.version === 1n, "binding fully populated at v1");
// epoch-field validation at mint
await mustRevert(() => c.mintTask.staticCall(A(deployer), A(publisher), A(judge), TD, TH, "u",
  { ...terms, epochLength: 86400n }), "epoch fields must be both zero or both set");

// VAULT: money literally in the token
const vault1 = await c.vaultOf(1);
ok(vault1 !== ethers.ZeroAddress && vault1 !== cAddr, "vault is a distinct per-token account");
await (await c.connect(funder).fundTask(1, ethers.parseEther("3"), { value: ethers.parseEther("3") })).wait();
await (await c.connect(funder2).fundTask(1, ethers.parseEther("1"), { value: ethers.parseEther("1") })).wait();
ok(await provider.getBalance(vault1) === ethers.parseEther("4"), "vault address holds 4 ETH (explorer-visible)");
ok(await c.escrowBalanceOf(1) === ethers.parseEther("4"), "escrowBalanceOf == live vault balance");
// vault lock: nobody can drain
const vaultC = new ethers.Contract(vault1, TV.abi, provider);
await mustRevert(() => vaultC.connect(deployer).payout.staticCall(ethers.ZeroAddress, A(deployer), 1n), "owner cannot drain vault");
await mustRevert(() => vaultC.connect(publisher).payout.staticCall(ethers.ZeroAddress, A(publisher), 1n), "publisher cannot drain vault");
await mustRevert(() => vaultC.connect(judge).payout.staticCall(ethers.ZeroAddress, A(judge), 1n), "judge cannot drain vault");
// direct transfer to vault = unattributed gift, counts as escrow
await (await rando.sendTransaction({ to: vault1, value: ethers.parseEther("0.5") })).wait();
ok(await c.escrowBalanceOf(1) === ethers.parseEther("4.5"), "direct vault deposit counts as escrow (gift)");

// authority separation
await mustRevert(() => c.connect(deployer).updateTask.staticCall(1, TD, TH2), "owner cannot publish");
await mustRevert(() => c.connect(judge).updateTask.staticCall(1, TD, TH2), "judge cannot publish");
await mustRevert(() => c.connect(publisher).setAcceptanceAuthority.staticCall(1, A(rando)), "publisher cannot move judgment");

// freeze binds content, not tender
await (await c.connect(publisher).freezeTask(1)).wait();
await mustRevert(() => c.connect(publisher).updateTask.staticCall(1, TD, TH2), "update after freeze");
await (await c.connect(publisher).setTaskURI(1, "ipfs://mirror")).wait();
ok((await c.taskOf(1)).version === 1n, "setTaskURI never bumps version");

// judged settlement pays FROM THE VAULT
await (await c.connect(worker).submitFulfillment(1, sha("deliverable-1"), "ipfs://r1")).wait();
const s1 = await c.submissionOf(1, 1);
ok(s1.fulfiller === A(worker) && s1.taskVersion === 1n, "submission records fulfiller + cited version");
await mustRevert(() => c.connect(worker).acceptFulfillment.staticCall(1, 1), "non-judge cannot accept");
await mustRevert(() => c.connect(worker).settleFulfillment.staticCall(1, 1, "0x"), "machine path closed on judged task");
const before1 = await provider.getBalance(A(worker));
await (await c.connect(judge).acceptFulfillment(1, 1)).wait();
ok((await provider.getBalance(A(worker))) - before1 === ethers.parseEther("1"), "worker paid 1 ETH from vault");
ok(await provider.getBalance(vault1) === ethers.parseEther("3.5"), "vault balance reduced by exactly the reward");
await mustRevert(() => c.connect(judge).acceptFulfillment.staticCall(1, 1), "double-accept forbidden");

// reject is terminal
await (await c.connect(worker).submitFulfillment(1, sha("deliverable-2"), "")).wait();
await (await c.connect(judge).rejectFulfillment(1, 2)).wait();
await mustRevert(() => c.connect(judge).acceptFulfillment.staticCall(1, 2), "rejected can never be accepted");

// maxCompletions bound (=2)
await (await c.connect(worker).submitFulfillment(1, sha("deliverable-3"), "")).wait();
await (await c.connect(judge).acceptFulfillment(1, 3)).wait();
ok(await c.completionsOf(1) === 2n, "completions = 2 (bound reached)");
await mustRevert(() => c.connect(worker).submitFulfillment.staticCall(1, sha("late"), ""), "submission after exhaustion");

// cancel + pro-rata reclaim over LIVE vault balance (2.5 remain; 3:1 contributions; gift shared)
await mustRevert(() => c.connect(funder).reclaimEscrow.staticCall(1), "reclaim while live");
await (await c.connect(publisher).cancelTask(1)).wait();
const tx1 = await (await c.connect(funder).reclaimEscrow(1)).wait();
// assert on the receipt's event, not a wallet balance delta: ethers caches
// getBalance within a block and can silently collapse before/after to zero
const rec1 = tx1.logs.map((l) => { try { return c.interface.parseLog(l); } catch { return null; } })
                     .find((x) => x?.name === "EscrowReclaimed");
ok(rec1.args[1] === A(funder) && rec1.args[2] === ethers.parseEther("1.875"),
   "funder reclaims 2.5 * 3/4 = 1.875 (gift shared pro rata)");
const tx2 = await (await c.connect(funder2).reclaimEscrow(1)).wait();
const ev2 = tx2.logs.map(l => { try { return c.interface.parseLog(l); } catch { return null; } })
  .find(e => e && e.name === "EscrowReclaimed");
ok(ev2 && ev2.args[2] === ethers.parseEther("0.625"), "funder2 reclaims 0.625 (EscrowReclaimed amount)");
ok(await c.escrowBalanceOf(1) === 0n, "vault drained exactly");
await mustRevert(() => c.connect(deployer).reclaimResidual.staticCall(1), "no residual when gifts were consumed by rewards");
ok((await c.taskOf(1)).taskHash === TH && (await c.taskOf(1)).version === 1n, "cancel touched no binding state");

// ---- token 2: MACHINE settlement (hashlock, permissionless) --------------------
const answer = ethers.toUtf8Bytes("42");
// two slots and two rewards: under v3.0 a Pending submission RESERVES both, so the
// copied "thief" submission below has to be affordable in order to exist at all.
await (await c.mintTask(A(deployer), A(publisher), hlAddr, TD, TH, "u",
  { ...terms, maxCompletions: 2n })).wait();
await mustRevert(() => hashlock.connect(rando).commitAnswer.staticCall(cAddr, 2, sha(answer)),
  "only update authority commits the answer");
await (await hashlock.connect(publisher).commitAnswer(cAddr, 2, sha(answer))).wait();
await mustRevert(() => hashlock.connect(publisher).commitAnswer.staticCall(cAddr, 2, sha("43")),
  "set-once answer (no moving goalposts)");
await (await c.connect(funder).fundTask(2, ethers.parseEther("2"), { value: ethers.parseEther("2") })).wait();
// fulfiller commits answer BOUND TO THEIR ADDRESS
const commitment = ethers.sha256(ethers.concat([answer, A(worker)]));
await (await c.connect(worker).submitFulfillment(2, commitment, "")).wait();
// wrong proof: reverts, submission stays Pending (not a rejection)
await mustRevert(() => c.connect(worker).settleFulfillment.staticCall(2, 1, ethers.toUtf8Bytes("41")), "wrong proof fails");
ok((await c.submissionOf(2, 1)).status === 0n, "failed verification leaves submission Pending");
// thief copies the commitment -> cannot settle their own submission
await (await c.connect(rando).submitFulfillment(2, commitment, "")).wait();
await mustRevert(() => c.connect(rando).settleFulfillment.staticCall(2, 2, answer), "copied commitment binds original fulfiller");
// right proof, called by a THIRD PARTY, pays the submission's fulfiller — no judge anywhere
const stx = await (await c.connect(rando).settleFulfillment(2, 1, answer)).wait();
const sev = stx.logs.map(l => { try { return c.interface.parseLog(l); } catch { return null; } })
  .find(e => e && e.name === "FulfillmentAccepted");
ok(sev && sev.args[2] === A(worker) && sev.args[3] === ethers.parseEther("1"),
   "machine settlement: solve it and the vault pays, no one in the loop");
ok((await c.escrowBalanceOf(2)) === ethers.parseEther("1") && (await c.lockedEscrowOf(2)) === ethers.parseEther("1"),
   "the thief's still-Pending submission keeps the second reward locked, not stolen");

// ---- token 3: EPOCH PACING (standing tender: 1/day) ----------------------------
await (await c.mintTask(A(deployer), A(publisher), A(judge), TD, TH, "u",
  { ...terms, maxCompletions: 0n, epochLength: 86400n, maxCompletionsPerEpoch: 1n })).wait();
await (await c.connect(funder).fundTask(3, ethers.parseEther("5"), { value: ethers.parseEther("5") })).wait();
await (await c.connect(worker).submitFulfillment(3, sha("day1"), "")).wait();
await (await c.connect(worker).submitFulfillment(3, sha("day1b"), "")).wait();
await (await c.connect(judge).acceptFulfillment(3, 1)).wait();
await mustRevert(() => c.connect(judge).acceptFulfillment.staticCall(3, 2), "epoch exhausted (1/day)");
await warp(86400 + 5); // next day
await (await c.connect(judge).acceptFulfillment(3, 2)).wait();
ok(await c.completionsOf(3) === 2n, "next epoch settles: the point-card inverse, paced");

// ---- token 4: JURY PANEL (K-of-N judged authority) -----------------------------
const panel = await new ethers.ContractFactory(JP.abi, JP.bin, deployer)
  .deploy([A(j1), A(j2), A(j3)], 2, 3n * 86400n);
await panel.waitForDeployment();
const panelAddr = await panel.getAddress();
await (await c.mintTask(A(deployer), A(publisher), panelAddr, TD, TH, "u", terms)).wait();
await (await c.connect(funder).fundTask(4, ethers.parseEther("2"), { value: ethers.parseEther("2") })).wait();
await (await c.connect(worker).submitFulfillment(4, sha("panel-work"), "")).wait();
await mustRevert(() => c.connect(worker).settleFulfillment.staticCall(4, 1, "0x"), "panel is judged, machine path closed");
await mustRevert(() => panel.connect(rando).vote.staticCall(cAddr, 4, 1, true), "non-juror cannot vote");
const before4 = await provider.getBalance(A(worker));
await (await panel.connect(j1).vote(cAddr, 4, 1, true)).wait();
await (await panel.connect(j2).vote(cAddr, 4, 1, true)).wait(); // 2-of-3 -> accept
ok((await provider.getBalance(A(worker))) - before4 === ethers.parseEther("1"), "2-of-3 quorum settles and pays");
// timeout default rejection, finalizable by anyone
await (await c.connect(worker).submitFulfillment(4, sha("panel-work-2"), "")).wait();
await (await panel.connect(j1).vote(cAddr, 4, 2, true)).wait(); // window opens
await warp(3 * 86400 + 5);
await (await panel.connect(rando).finalizeTimeout(cAddr, 4, 2)).wait();
ok((await c.submissionOf(4, 2)).status === 2n, "stalled case defaults to rejection on timeout");

// ---- token 5: on-chain document ------------------------------------------------
const doc = ethers.toUtf8Bytes("# Build the verifier\nExact spec follows.");
await (await c.mintTask(A(deployer), A(publisher), A(judge), ethers.sha256(doc), TH, "u", terms)).wait();
await mustRevert(() => c.connect(publisher).publishTaskDocument.staticCall(5, ethers.toUtf8Bytes("wrong")), "publish wrong bytes");
await (await c.connect(publisher).publishTaskDocument(5, doc)).wait();
ok(await c.hasOnchainTaskDocument(5) && (await c.taskOf(5)).version === 1n, "disclosure without version change");
await mustRevert(() => c.connect(publisher).updateTask.staticCall(5, sha("new doc"), TH2), "tdHash change must go atomic route");
await (await c.connect(publisher).updateTaskWithDocument(5, ethers.toUtf8Bytes("new doc"), TH2)).wait();
ok((await c.taskOf(5)).version === 2n && (await c.taskOf(5)).tdHash === sha("new doc"), "atomic doc+binding update");

// ---- token 6: gift residual goes to the token OWNER, never to funders ----------
await (await c.mintTask(A(deployer), A(publisher), A(judge), TD, TH, "u", terms)).wait();
await (await c.connect(funder).fundTask(6, ethers.parseEther("2"), { value: ethers.parseEther("2") })).wait();
await (await rando.sendTransaction({ to: await c.vaultOf(6), value: ethers.parseEther("1") })).wait(); // anonymous gift
await mustRevert(() => c.connect(deployer).reclaimResidual.staticCall(6), "residual locked while tender live");
await (await c.connect(publisher).cancelTask(6)).wait();
const txr = await (await c.connect(funder).reclaimEscrow(6)).wait();
const evr = txr.logs.map(l => { try { return c.interface.parseLog(l); } catch { return null; } })
  .find(e => e && e.name === "EscrowReclaimed");
ok(evr && evr.args[2] === ethers.parseEther("2"), "funder gets contributions back, NOT the gift");
await mustRevert(() => c.connect(rando).reclaimResidual.staticCall(6), "only token owner takes residual");
const txo = await (await c.connect(deployer).reclaimResidual(6)).wait();
const evo = txo.logs.map(l => { try { return c.interface.parseLog(l); } catch { return null; } })
  .find(e => e && e.name === "ResidualReclaimed");
ok(evo && evo.args[1] === A(deployer) && evo.args[2] === ethers.parseEther("1"),
   "gift residual accrues to the token owner");
ok(await c.escrowBalanceOf(6) === 0n, "vault 6 drained exactly");

// ---- tokens 7-9: the v3.0 free-look guard --------------------------------------
// A demander must not be able to read a delivery and then keep both the work and
// the money. Every escape route is closed here.
const P = (n) => ethers.parseEther(String(n));
await (await c.mintTask(A(deployer), A(publisher), A(judge), TD, TH, "u",
  { ...terms, maxCompletions: 1n, judgmentWindow: 3600n })).wait();
await (await c.connect(funder).fundTask(7, P(1), { value: P(1) })).wait();
await (await c.connect(worker).submitFulfillment(7, sha("consulting report"), "https://d.example/r.pdf")).wait();
ok(await c.pendingOf(7) === 1n && await c.lockedEscrowOf(7) === P(1),
   "a delivery reserves a slot AND locks its reward");
await mustRevert(() => c.connect(rando).submitFulfillment.staticCall(7, sha("sock"), ""),
  "a sock puppet taking the last slot from under a Pending delivery");
await (await c.connect(publisher).cancelTask(7)).wait();      // read it, then walk away
await mustRevert(() => c.connect(funder).reclaimEscrow.staticCall(7), "reclaim while a delivery is Pending");
await mustRevert(() => c.connect(deployer).reclaimResidual.staticCall(7), "residual while a delivery is Pending");
await mustRevert(() => c.connect(worker).claimUnjudged.staticCall(7, 1), "claiming before the judgment window ends");
await warp(3601);
const txu = await (await c.connect(rando).claimUnjudged(7, 1)).wait();   // permissionless
const namesU = txu.logs.map(l => { try { return c.interface.parseLog(l)?.name; } catch { return null; } });
ok(namesU.includes("FulfillmentClaimedUnjudged"), "a default is recorded distinctly from a ruling");
const evu = txu.logs.map(l => { try { return c.interface.parseLog(l); } catch { return null; } })
  .find(e => e && e.name === "FulfillmentAccepted");
ok(evu && evu.args[2] === A(worker) && evu.args[3] === P(1),
   "silence past the deadline pays the worker in full, even after cancellation");
ok(await c.escrowBalanceOf(7) === 0n, "the demander recovered nothing by staying silent");

// the same guard must not become a way to be paid for garbage on the machine path
await (await c.mintTask(A(deployer), A(publisher), hlAddr, TD, TH, "u",
  { ...terms, maxCompletions: 1n, judgmentWindow: 3600n })).wait();
await (await c.connect(funder).fundTask(8, P(1), { value: P(1) })).wait();
await (await c.connect(rando).submitFulfillment(8, sha("garbage"), "")).wait();
await warp(7200);
await mustRevert(() => c.connect(rando).claimUnjudged.staticCall(8, 1),
  "waiting out the clock on a machine-settled tender (code judged, and said no)");
// ...but junk must not be able to squat the slot forever either: with no judge to
// reject it, releaseExpired is what stops a machine tender being bricked
ok(await c.pendingOf(8) === 1n && await c.lockedEscrowOf(8) === P(1),
   "the junk submission is holding a machine tender's only slot and its whole vault");
await mustRevert(() => c.connect(judge).releaseExpired.staticCall(7, 1), "releaseExpired on a JUDGED tender");
const txrel = await (await c.connect(worker).releaseExpired(8, 1)).wait();   // permissionless
const namesR = txrel.logs.map(l => { try { return c.interface.parseLog(l)?.name; } catch { return null; } });
ok(namesR.includes("SubmissionReleased") && namesR.includes("FulfillmentRejected"),
   "an expiry is recorded distinctly from a judge's ruling");
ok(await c.pendingOf(8) === 0n && await c.lockedEscrowOf(8) === 0n,
   "the slot and the reward are freed, and the tender lives again");
await (await c.connect(worker).submitFulfillment(8, sha("second attempt"), "")).wait();
ok(await c.pendingOf(8) === 1n, "a genuine solver can take the freed slot");
await (await c.connect(worker).releaseExpired.staticCall(8, 2).then(() => { throw 0; }, () => {}));
ok(true, "and cannot be released before its own window elapses");

// an explicit, on-the-record rejection is what releases a reservation
await (await c.mintTask(A(deployer), A(publisher), A(judge), TD, TH, "u",
  { ...terms, maxCompletions: 1n, judgmentWindow: 3600n })).wait();
await (await c.connect(funder).fundTask(9, P(1), { value: P(1) })).wait();
await (await c.connect(worker).submitFulfillment(9, sha("junk"), "")).wait();
await (await c.connect(publisher).cancelTask(9)).wait();
await mustRevert(() => c.connect(funder).reclaimEscrow.staticCall(9), "reclaim before the junk is ruled on");
await (await c.connect(judge).rejectFulfillment(9, 1)).wait();
ok(await c.pendingOf(9) === 0n, "an on-the-record rejection releases the reservation");
const txf = await (await c.connect(funder).reclaimEscrow(9)).wait();
const evf = txf.logs.map(l => { try { return c.interface.parseLog(l); } catch { return null; } })
  .find(e => e && e.name === "EscrowReclaimed");
ok(evf && evf.args[2] === P(1), "and only then is the funder refunded in full");


// ---- token 10: a default is still a PACED settlement --------------------------
// On a standing tender the provider may deliver several periods' work at once
// (pacing bounds settlement, not submission). If the judge then goes silent, the
// default claims must still come one per epoch, or a silent judge would drain the
// whole budget at once — the very thing the cadence exists to prevent.
await (await c.mintTask(A(deployer), A(publisher), A(judge), TD, TH, "u",
  { ...terms, maxCompletions: 5n, epochLength: 86400n, maxCompletionsPerEpoch: 1n, judgmentWindow: 3600n })).wait();
await (await c.connect(funder).fundTask(10, P(5), { value: P(5) })).wait();
for (let i = 0; i < 5; i++) {
  await (await c.connect(worker).submitFulfillment(10, sha("period-" + i), "")).wait();
}
ok(await c.pendingOf(10) === 5n, "five periods delivered at once, all five reserved");
await warp(3601);                                   // the judge says nothing at all
await (await c.connect(worker).claimUnjudged(10, 1)).wait();
const ep = BigInt((await provider.getBlock("latest", true)).timestamp) / 86400n;
ok(await c.completionsInEpochOf(10, ep) === 1n, "the first default settles and fills the epoch");
await mustRevert(() => c.connect(worker).claimUnjudged.staticCall(10, 2),
  "a second default in the same epoch — silence must not outrun the cadence");
ok(await c.escrowBalanceOf(10) === P(4), "the budget is intact: 4 of 5 still escrowed");
await warp(86400);
await (await c.connect(worker).claimUnjudged(10, 2)).wait();
ok(await c.completionsOf(10) === 2n && await c.escrowBalanceOf(10) === P(3),
   "the queued claim is not lost: it lands in the next epoch");


// ---- token 11: an external judge's timeout vs the kernel's -------------------
// A K-of-N panel defaults to REJECT when quorum is not reached; the kernel defaults
// to PAY when nobody rules. They disagree, and the earlier deadline decides. A panel
// whose window is the shorter one keeps its authority; configured the other way it
// would be decorative, so this asserts the ordering the specification requires.
const jurors2 = [A(j1), A(j2), A(j3)];
const panel2 = await new ethers.ContractFactory(JP.abi, JP.bin, deployer).deploy(jurors2, 2, 100n);
await panel2.waitForDeployment();
await (await c.mintTask(A(deployer), A(publisher), await panel2.getAddress(), TD, TH, "u",
  { ...terms, maxCompletions: 1n, judgmentWindow: 400n })).wait();   // 400 > the panel's 100
await (await c.connect(funder).fundTask(11, P(1), { value: P(1) })).wait();
await (await c.connect(worker).submitFulfillment(11, sha("release"), "")).wait();
await (await panel2.connect(j1).vote(cAddr, 11, 1, true)).wait();     // one vote, then silence
await warp(120);                                                      // panel window gone, kernel's not
await mustRevert(() => c.connect(worker).claimUnjudged.staticCall(11, 1),
  "claiming by default while the kernel's window is still open");
await (await panel2.connect(rando).finalizeTimeout(cAddr, 11, 1)).wait();
ok((await c.submissionOf(11, 1)).status === 2n,
   "the panel's default lands first because its window is the shorter one");
await warp(400);
await mustRevert(() => c.connect(worker).claimUnjudged.staticCall(11, 1),
  "claiming a submission the panel had already rejected");
ok(await c.pendingOf(11) === 0n && await c.escrowBalanceOf(11) === P(1),
   "the rejection freed the slot and the reward, and no money moved");


// ---- tokens 12-13: the judge's right to refuse expires with the window ---------
// A judge that stays silent for the whole window must not then be able to front-run
// the fulfiller's claim with a refusal; and a demander must not be able to escape the
// deadline by swapping the judgment slot after the work has arrived.
await (await c.mintTask(A(deployer), A(publisher), A(judge), TD, TH, "u",
  { ...terms, maxCompletions: 2n, judgmentWindow: 3600n })).wait();
await (await c.connect(funder).fundTask(12, P(2), { value: P(2) })).wait();
await (await c.connect(worker).submitFulfillment(12, sha("delivery-a"), "")).wait();
await (await c.connect(judge).rejectFulfillment(12, 1)).wait();
ok((await c.submissionOf(12, 1)).status === 2n, "inside the window the judge may still refuse");
await (await c.connect(worker).submitFulfillment(12, sha("delivery-b"), "")).wait();
await warp(3601);
await mustRevert(() => c.connect(judge).rejectFulfillment.staticCall(12, 2),
  "refusing after the judgment window has closed");
const txlate = await (await c.connect(worker).claimUnjudged(12, 2)).wait();
const evlate = txlate.logs.map(l => { try { return c.interface.parseLog(l); } catch { return null; } })
  .find(e => e && e.name === "FulfillmentAccepted");
ok(evlate && evlate.args[2] === A(worker),
   "so the claim cannot be front-run: silence really does pay the fulfiller");

// the settlement mode is a snapshot taken when the delivery was made
await (await c.mintTask(A(deployer), A(publisher), A(judge), TD, TH, "u",
  { ...terms, maxCompletions: 1n, judgmentWindow: 3600n })).wait();
await (await c.connect(funder).fundTask(13, P(1), { value: P(1) })).wait();
await (await c.connect(worker).submitFulfillment(13, sha("delivery-c"), "")).wait();
ok((await c.submissionOf(13, 1)).machineSettled === false, "the delivery records that a judge held the slot");
await (await c.connect(judge).setAcceptanceAuthority(13, hlAddr)).wait();   // swap in a verifier
await warp(3601);
await mustRevert(() => c.connect(worker).releaseExpired.staticCall(13, 1),
  "releasing a delivery that was made under a judge, after a verifier was swapped in");
const txsnap = await (await c.connect(worker).claimUnjudged(13, 1)).wait();
const evsnap = txsnap.logs.map(l => { try { return c.interface.parseLog(l); } catch { return null; } })
  .find(e => e && e.name === "FulfillmentAccepted");
ok(evsnap && evsnap.args[2] === A(worker),
   "the deadline follows the delivery, not the live judgment slot");


console.log(`\nSMOKE RESULT: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
