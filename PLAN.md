# Tokin — Launch Plan

> **Status:** planning. Nothing deployed. Nothing irreversible has happened yet.
>
> Sibling project to [`obstok`](../obstok) — that one launched a meme coin on Solana from first principles. This one does the same on an Ethereum L2 (Base). The intent is identical: a fair launch performed in obscurity, end-to-end documentation, no shortcuts (no pump.fun, no Clanker, no Virtuals).

---

## 1. Goal & non-goals

**Goal.** Mint, list, and renounce a meme coin on Base mainnet using only first-principles tooling (Foundry + direct DEX calls), and document every step so a stranger could repeat it.

**Non-goals.**
- Make money. The token is intentionally worthless and explicitly described as such on-chain metadata.
- Market the token. Like obstok, the launch happens in obscurity — no socials, no Telegram, no shill.
- Build a "real" DeFi protocol. No staking, no farms, no vesting, no team allocation. Just an ERC-20 and a pool.
- Maximise gas efficiency or use clever Solidity. The contract should be boringly readable.

---

## 2. Design — the EVM "trust trifecta"

obstok's three irreversibility guarantees translate to EVM as follows:

| obstok (Solana / Token-2022)        | tokin (Base / ERC-20)                                    |
|---                                  |---                                                         |
| Renounce mint authority             | Contract has **no mint function** post-deploy (`_mint` only in constructor) |
| Inject 100% of supply into LP       | Same — constructor mints to deployer, deployer adds all to pool |
| Burn LP tokens                      | Transfer LP tokens to `0x000000000000000000000000000000000000dEaD` |

Additional EVM-specific guarantees worth stacking on:

- **No owner.** The contract does not inherit `Ownable`. No admin, no pause, no fee-toggle, no blacklist.
- **No proxy.** Direct deploy, not behind a UUPS/Transparent proxy. The bytecode at the token address is the final bytecode.
- **No transfer hooks.** Standard `_update`/`_transfer` only — nothing that lets the contract intercept trades. Honeypot scanners flag anything else.
- **Verified source on BaseScan.** Without verification, scanners can't statically prove the above and the token looks suspicious by default.

---

## 3. Stack choices

| Layer            | Choice                                  | Why                                                                                 |
|---               |---                                      |---                                                                                  |
| Chain            | **Base** (chain ID 8453)                | Decided. Strongest memecoin culture of any L2; native CCTP bridge; cheap gas.       |
| Token standard   | **ERC-20** (OpenZeppelin v5)            | Universally supported. No ERC-1363/777 tricks.                                      |
| Decimals         | **18**                                  | EVM convention. Differs from obstok's 6 — don't transplant the Solana number.       |
| Supply           | **1,000,000,000** (1B)                  | Matches obstok. Conventional memecoin supply.                                       |
| DEX              | **Aerodrome — basic *volatile* pool**   | Closest EVM analog to Raydium CPMM. The relevant axis is *cpAMM vs concentrated liquidity*, not Uniswap version number — see §10. Native to Base. Alternative: Uniswap v2 (also deployed on Base). |
| LP fate          | **Burn to `0x...dEaD`**                 | Decided. Mirrors obstok. Alternative was UNCX time-lock; rejected for purity.       |
| Dev tooling      | **Foundry** (`forge`, `cast`, `anvil`)  | Faster, fewer moving parts than Hardhat. Built-in fuzzing. Native Solidity scripts. |
| Wallet           | **Rabby** (mainnet signing)             | Better tx simulation than MetaMask, EVM-native. Phantom equivalent.                 |
| Metadata hosting | **Cloudflare Pages**                    | Same pattern as obstok — free, CORS-friendly. Hosts logo + token-list JSON.         |
| Verification     | **BaseScan via `forge verify-contract`**| Required for trust signals.                                                         |

---

## 4. Architecture (one-pager)

```
                     ┌────────────────────┐
                     │  Deployer wallet   │  fresh EOA, funded with ~0.01 ETH
                     │  (ephemeral EOA)   │  on Base via bridge or CCTP
                     └─────────┬──────────┘
                               │
              ┌────────────────┼────────────────────────────┐
              │                │                            │
              ▼                ▼                            ▼
      ┌──────────────┐  ┌──────────────────┐     ┌────────────────────┐
      │ Tokin.sol  │  │ Aerodrome Router │     │  Cloudflare Pages  │
      │ ERC-20, 1B   │  │  addLiquidity()  │     │  tokin.pages.dev │
      │ no owner     │  │  → mints LP token│     │  /token-list.json  │
      │ no mint fn   │  │                  │     │  /logo.png         │
      └──────┬───────┘  └────────┬─────────┘     └────────────────────┘
             │                   │
             │ 100% supply       │ LP tokens
             ▼                   ▼
      ┌──────────────┐    ┌──────────────┐
      │ AERO pool    │    │ 0x000...dEaD │  (LP burned — irreversible)
      │ SQUITCH/WETH │    └──────────────┘
      └──────────────┘
```

---

## 5. Phases

Numbered for the runsheet to follow during execution. Each phase has an explicit *exit criterion* — don't proceed until met.

### Phase 0 — Repo scaffolding (no chain interaction)
- [ ] `forge init contracts/` inside this repo
- [ ] OZ v5 as dep: `forge install OpenZeppelin/openzeppelin-contracts`
- [ ] Add `foundry.toml` profile, remappings, solc 0.8.26 (or latest stable)
- [ ] `.gitignore` for `out/`, `cache/`, `broadcast/`, `.env`
- [ ] **Exit:** `forge build` green.

### Phase 1 — Contract (`contracts/src/Tokin.sol`)
Target: < 30 lines including imports. Sketch:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Tokin is ERC20, ERC20Permit {
    constructor(address recipient)
        ERC20("Tokin", "SQUITCH")
        ERC20Permit("Tokin")
    {
        _mint(recipient, 1_000_000_000 * 10 ** decimals());
    }
}
```

Notes:
- `ERC20Permit` (EIP-2612) lets users approve via signature instead of a separate `approve()` tx — one combined tx instead of two on first swap. Standard since ~2022, OZ ships it by default, aggregators (1inch, Uniswap UI, CowSwap) auto-detect and use it. Keep it.
- No `Ownable`, no `mint()`, no `burn()` exposed publicly. Holders can still burn by sending to `0x...dEaD` if they want.
- No fee-on-transfer, no max-tx, no anti-bot. Aerodrome and routers hate FoT tokens; keeping it clean = better routing.

- [ ] **Exit:** contract compiles, no warnings.

### Phase 2 — Tests (`contracts/test/Tokin.t.sol`)
Foundry test suite. Cover:
- Total supply == 1B * 10^18.
- Deployer receives full supply.
- `transfer` works between EOAs.
- `permit` works (signature → allowance).
- No external `mint` function exposes minting capability (sanity test that the selector doesn't exist even after refactors).
- Fuzz: random `transfer` amounts, invariant `totalSupply` unchanged.

- [ ] **Exit:** `forge test -vvv` all green, gas snapshot saved.

### Phase 3 — Local fork dry-run
Use Foundry's mainnet fork to rehearse end-to-end without spending money:

```
anvil --fork-url $BASE_RPC_URL --chain-id 8453
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
forge script script/SeedPool.s.sol --rpc-url http://localhost:8545 --broadcast
forge script script/BurnLP.s.sol --rpc-url http://localhost:8545 --broadcast
```

This catches Aerodrome integration bugs (wrong router address, wrong selector, wrong pool flavour) before they cost real ETH.

- [ ] **Exit:** All three scripts run cleanly on the fork; balances at the end match expectations (deployer 0 SQUITCH, dEaD has all the LP).

### Phase 4 — Base Sepolia full rehearsal *(optional but recommended)*
Same scripts, against Base Sepolia. Catches RPC differences and verification flow. Aerodrome may not exist on Sepolia — if not, use the testnet Uniswap v2 deployment and treat the prod swap as the one untested step.

- [ ] **Exit:** Token deployed on Base Sepolia, verified on sepolia.basescan.org, pool seeded, LP burned, all reads return expected state.

### Phase 5 — Deployer wallet prep (mainnet)
- Generate a fresh keypair (`cast wallet new`), store privkey in a `.env` not committed.
- Bridge ~0.01 ETH to the EOA on Base via [bridge.base.org](https://bridge.base.org). Budget:
  - Deploy: ~0.0001 ETH
  - Approve + addLiquidity: ~0.0001 ETH
  - Burn LP: ~0.00005 ETH
  - **Seed liquidity:** decide this number deliberately — see §8.
  - Rounding/headroom: 2x everything.

- [ ] **Exit:** wallet shows expected ETH on basescan.org, privkey is not in git.

### Phase 6 — Deploy on Base mainnet
```
forge script contracts/script/Deploy.s.sol \
  --rpc-url $BASE_RPC_URL --broadcast \
  --verify --etherscan-api-key $BASESCAN_API_KEY
```

- [ ] Contract address recorded.
- [ ] Source verified on BaseScan (green "Contract" tab with source code).
- [ ] **Exit:** `cast call $TOKEN "totalSupply()(uint256)"` returns 1e27.

### Phase 7 — Create pool + seed liquidity (Aerodrome)
Two-step:
1. `Router.addLiquidity(tokin, WETH, false /* stable=false */, supply, ethAmount, ..., deployer, deadline)` — `false` selects a volatile (cpAMM) pool. Aerodrome will create it on first call.
2. Confirm the pool address via `PoolFactory.getPool(tokin, WETH, false)` and verify LP token balance on the deployer.

Reference addresses on Base (verify before pasting into a script):
- Aerodrome Router: `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43`
- Aerodrome PoolFactory: `0x420DD381b31aEf6683db6B902084cB0FFECe40Da`
- WETH: `0x4200000000000000000000000000000000000006`

- [ ] **Exit:** pool exists, deployer holds all LP tokens, deployer's SQUITCH balance is 0.

### Phase 8 — Burn LP
```
cast send $LP_TOKEN "transfer(address,uint256)" \
  0x000000000000000000000000000000000000dEaD $LP_BALANCE \
  --private-key $PK --rpc-url $BASE_RPC_URL
```

- [ ] **Exit:** `balanceOf(deployer)` == 0 on LP token; `balanceOf(0x...dEaD)` == previous LP balance.

### Phase 9 — Metadata + listings
- [ ] Logo to `token-metadata/logo.png`, deploy to Cloudflare Pages (reuse obstok's `_headers` pattern for CORS).
- [ ] Token list JSON (Uniswap token-list schema) at `token-metadata/token-list.json` — name, symbol, decimals, address, chainId 8453, logoURI.
- [ ] DexScreener auto-indexes from first swap; "Enhance Token Info" form (~$300 USDC) is optional and skip-worthy for an obscurity launch.
- [ ] Optional submissions: trustwallet/assets PR, base-org/web tokens repo, Coingecko (high SLA, often rejected without volume).

### Phase 10 — Verify the trifecta on-chain
A short shell script that anyone can run to confirm the launch is honest:
```
cast call $TOKEN "totalSupply()(uint256)"          # 1e27
cast call $TOKEN "balanceOf(address)(uint256)" $POOL   # 1e27
cast call $LP    "balanceOf(address)(uint256)" 0x...dEaD  # == total LP supply
cast code $TOKEN | wc -c                            # nonzero (deployed)
```

- [ ] **Exit:** All four reads return the expected values, screenshotted into `docs/summary.md`.

### Phase 11 — Post-launch documentation
- [ ] `docs/summary.md` with addresses, screenshots, links.
- [ ] `docs/runsheet.md` — convert this plan into the as-built record (delete branches not taken, paste real tx hashes).
- [ ] `docs/gotchas.md` — what differed from this plan, what surprised you.
- [ ] `docs/glossary.md` — EVM/L2 terms a Solana person might not have (calldata, EIP-1559 vs blob base fee, permit, router vs pool, etc.).

---

## 6. Final repo layout (target)

```
tokin/
├── README.md                   # one-paragraph pitch + addresses (post-launch)
├── PLAN.md                     # this file
├── contracts/
│   ├── foundry.toml
│   ├── src/Tokin.sol
│   ├── test/Tokin.t.sol
│   └── script/
│       ├── Deploy.s.sol
│       ├── SeedPool.s.sol
│       └── BurnLP.s.sol
├── docs/
│   ├── summary.md
│   ├── runsheet.md
│   ├── gotchas.md
│   └── glossary.md
├── token-metadata/
│   ├── logo.png
│   ├── token-list.json
│   └── _headers              # CORS, copied from obstok
└── tools/
    └── verify-trifecta.sh    # the §10 checks as a script
```

---

## 7. What's *different* from obstok (call-outs for documentation)

Things future-you (or a reader) will trip on if they assume parity with the Solana launch:

1. **Decimals.** 18 here, 6 there. Don't reuse calculation snippets.
2. **"Renouncing" doesn't exist.** You don't call a renounce function — you write a contract that never had the privilege. This is *stronger* than Solana renunciation (which is a post-hoc transaction); on EVM the absence is structural in the bytecode.
3. **Metadata is off-chain.** Token-2022's on-chain metadata extension has no ERC-20 equivalent. Name/symbol live in the contract but logo/description live in token lists, which are *centralised social conventions*, not on-chain truth.
4. **LP token is a real ERC-20.** Aerodrome (and Uniswap v2) mint a standard ERC-20 representing your pool share. Burning it is `transfer(dEaD, balance)`. On Raydium you used a different mechanism — the verb is the same but the object isn't.
5. **Gas market.** Base inherits L1 blob fees. Right after an Ethereum congestion spike, Base gas can briefly 10x. Wait for a calm window before deploying; check basescan.org/gastracker.
6. **Wallet UX is worse.** Without a token list inclusion, Rabby/MetaMask will show "Unknown token" and warn on swaps. DexScreener will scan the contract and decide if it's a honeypot. Plain ERC-20 with verified source passes; anything fancy fails.
7. **Concentrated liquidity is a trap.** Uniswap v3 lets you pick a price range — for a memecoin with unknown future price, this is wrong almost always. Stick to Aerodrome volatile / Uniswap v2.
8. **No "freeze authority" surprise.** EVM has no equivalent default — there is just nothing to disable.

---

## 8. Decisions still owed before Phase 5

Don't bridge ETH until these are pinned:

- [ ] **Seed liquidity in ETH.** obstok used ~0.1 SOL (~$15 at launch). Base equivalent ≈ 0.005 ETH (~$15). Decide deliberately — initial price = `ETH_seeded / 1e9 SQUITCH`.
- [ ] **Token name and symbol.** Assume "Tokin" / "SQUITCH" unless you want otherwise.
- [ ] **Logo.** Reuse obstok's or new? If new, settle on PNG ≥ 512×512 transparent.
- [ ] **Description string for token list.** One sentence. State explicitly that it's worthless (mirrors obstok's honesty norm).
- [ ] **RPC provider.** Public Base RPC works but rate-limits; Alchemy/QuickNode free tier is fine. Pick one and pin it in `.env`.

---

## 9. Predicted gotchas (to be confirmed in `docs/gotchas.md` after launch)

Things I expect to bite, based on what bit obstok and what commonly bites Base launches:

- **BaseScan verification failing on Permit's domain separator** — `name` in `ERC20Permit` must exactly match `ERC20` name. Already correct in §1 contract sketch; flag if you change names.
- **Aerodrome `addLiquidity` reverting with insufficient amount** — the `amountMin` params need realistic slippage tolerance on first add (no prior pool to peg against). Use `0` for the very first add or pin tight to what you're depositing.
- **Wrong LP token address.** Aerodrome's pool *is* the LP token (one contract). Don't go hunting for a separate LP address — `getPool(...)` is what you transfer from.
- **CCTP-bridged ETH doesn't arrive instantly** — official Base bridge can take 10+ minutes. Bridge before you start.
- **Fish shell `$variable` expansion in `cast` commands** — `cast send` with hex args occasionally needs quoting that bash/zsh tolerate but fish doesn't. Test commands in a script, not interactively.
- **Etherscan API key vs BaseScan API key** — they're different services with different keys despite shared lineage. Use the BaseScan one for `--verify`.
- **DexScreener taking 5–30 min to index** after the first swap. The pool exists immediately, the dashboard does not.
- **Honeypot.is showing yellow flags** for permit-enabled tokens. Usually harmless but worth screenshotting and explaining.

---

## 10. Rejected alternatives (recorded so the choices are legible)

- **Uniswap version number is the wrong axis.** What matters is *cpAMM vs concentrated liquidity*:
  - **v2** = cpAMM, full-range, no decisions. What we want. Deployed on Base. Viable fallback if Aerodrome integration is painful.
  - **v3** = concentrated liquidity, must pick a tick range. Wrong tool for an unknown-price memecoin (a full-range v3 position is just a worse v2).
  - **v4** = singleton + hooks (launched Jan 2025, live on Base). At the core it's still concentrated liquidity — a no-hook v4 pool is v3 with cheaper deployment. Hooks *can* implement cpAMM behavior, but using one means trusting hook code, which cuts against the "no third parties" stance. Skip.
- **Clanker / Virtuals / pump-style launchpads** — defeats the educational purpose. Same rejection logic as obstok's "no pump.fun".
- **Arbitrum / Optimism / Blast** — all viable; Base wins for memecoin density and bridge UX. Documented in the question that led here.
- **UNCX / Team Finance LP lock** — recoverable after lock period, requires trusting a third-party contract. Burning is simpler and stronger. Documented for completeness; rejected.
- **Hardhat instead of Foundry** — slower iteration, JS toolchain, less idiomatic in 2026.
- **Custom token with team allocation / vesting / treasury** — diverges from obstok's "everything in the pool" purity. Out of scope.

---

## 11. Cost estimate

Pre-launch, ballpark, at ~2026 gas prices:

| Item                          | Cost                |
|---                            |---                  |
| Contract deploy               | ~$0.05              |
| BaseScan verification         | free                |
| Aerodrome `addLiquidity`      | ~$0.10              |
| LP burn `transfer`            | ~$0.02              |
| Seed liquidity (decide §8)    | ~$15 (suggested)    |
| Cloudflare Pages              | free                |
| RPC (Alchemy free tier)       | free                |
| **Total floor**               | **~$15.20**         |
| DexScreener Enhanced Info     | ~$300 (optional, skip) |

---

## 12. Next action

When ready to start: do Phase 0 (scaffolding) only, commit, and stop. Phases 1–4 can be done offline at any time. Phases 5+ are the irreversible ones — those wait for the right window (calm gas, undivided attention, all §8 decisions made).
