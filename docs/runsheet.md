# Launching a meme coin

This document was assembled while working through the process end-to-end.

## Upfront decisions

| Decision | Choice | Rationale |
|---|---|---|
| Chain | **Base (Ethereum L2)** | Strongest memecoin culture of any L2 due to  |
| Name | Tokin' | A joke about a koala with unfettered access to gumleaves |
| Symbol (ticker) | TOKIN | Not taken according to etherscan.io
| Token standard | **ERC-20** (OpenZeppelin v5) | Simple and universally supported by wallets etc. |
| Base asset | **???** | (ETH or USDC?) Most natural option for swaps. |
| DEX | **Uniswap v2** | Most popular, deployed on Base as well as Ethereum L1 |
| Liquidity locking | **Burn to `0x...dEaD`** | Purity, stronger trust signal than time-locking. |
| Total supply | **1 Billion** | A conventional amount for a memecoin supply. |
| Seed liquidity | **???** | (Minimum amount to account for Base fees, DEX fees, min pool size) |

## Install Foundry

[Foundry](https://www.getfoundry.sh/) is one of the two major development toolchains in the EVM ecosystem, along with [Hardhat](https://v2.hardhat.org/). Fetch and run the installer script:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Then run the installer itself:

```bash
foundryup
```

Check that the four Foundry tools are installed correctly:

```bash
forge --version # for building/testing/deploying smart contracts
cast --version # for transacting/querying on blockchains
anvil --version # for running a local Ethereum node
chisel --version # REPL for Solidity development
```

## Initialise the repo

Make sure the project's *root* is initialised with `git init`. Then, in the root folder:

```bash
forge init contracts/
```

This creates a standard Foundry project layout in a `contracts` subdirectory, adjacent to other folders for `docs`, `metadata` etc.

> [!WARNING]
> From this point onward, all `forge` commands must be run from inside the `contracts` folder.

Install the latest OpenZeppelin contract collection as a additional dependency to the forge standard library:

```bash
cd contracts
forge install OpenZeppelin/openzeppelin-contracts@v5.6.1
```

*why install the whole lot? I just get a stack of compiler warnings for contract code I am not using*

Update the default `foundry.toml` configuration to explicitly set the Solidy compiler version:

```bash
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.26"
```

*add the rpc endpoints and etherscan.io stuff later*

```bash
[rpc_endpoints]
# Keyless public endpoints — rate-limited but fine to start. Swap to a keyed
# provider (e.g. base = "${BASE_RPC_URL}") later if forking gets throttled.
base = "https://mainnet.base.org"
base_sepolia = "https://sepolia.base.org"

[etherscan]
base         = { key = "${BASESCAN_API_KEY}", chain = 8453 }
base_sepolia = { key = "${BASESCAN_API_KEY}", chain = 84532 }
```

Verify that the project successfully builds with no warnings:

```bash
forge build
```







