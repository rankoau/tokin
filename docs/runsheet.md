# Launching a meme coin

This document was assembled while working through the process end-to-end.

## Upfront decisions

| Decision | Choice | Rationale |
|---|---|---|
| Chain | **Base (Ethereum L2)** | Strongest memecoin culture of any L2 due to  |
| Name | **Tokin'** | A joke about a koala with unfettered access to gumleaves |
| Symbol (ticker) | **TOKIN** | Not taken according to etherscan.io
| Token standard | **ERC-20** (OpenZeppelin v5) | Simple and universally supported by wallets etc. |
| Base asset | **???** | (ETH or USDC?) Most natural option for swaps. |
| DEX | **Aerodrome** | Most suitable on Base for constant-product automated market maker deployments (cpAMM) |
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

Write an explicit `remappings.txt` to ensure that both `forge` and IDE plugins understand `@openzeppelin/*` import paths:

```bash
forge remappings > remappings.txt
```

*why install the whole lot? I just get a stack of compiler warnings for contract code I am not using*

Update the default `foundry.toml` configuration to explicitly set the Solidy compiler version and avoid a bunch of deprecation warnings:

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

Verify that the initialised project builds with no `solc` compiler warnings:

```bash
forge build
```

## Write the contract

All EVM fungible tokens conform to the long-established [ERC-20](https://ethereum.org/developers/docs/standards/tokens/erc-20/) standard. The standard defines the *interface* (`IERC20.sol`); while [OpenZeppelin](https://github.com/openzeppelin/openzeppelin-contracts) (a leading blockchain security company) provides a battle-tested *abstract implementation* (`ERC20.sol`) designed to be inherited from. Ultimately, a straight meme coin implementation contains nothing novel that OZ's v5 implementation doesn't do already except for minting its own supply from the constructor. Otherwise all that is required is to customise the name and ticker symbol.

(See [`/contracts/src/Tokin.sol`](../contracts/src/Tokin.sol))

> [!NOTE]
> `ERC20Permit` is the EIP-2612 extension to ERC-20 which was introduced to allow for approvals via off-chain signatures. ERC-20 works without it, but all basic tokens use this now because it makes using the token cheaper.

```bash
forge build # should be clean
```

## Write tests

This is an academic exercise, since OpenZeppelin's ERC20 implementations already have thorough coverage. Test suite files always use the `.t.sol` suffix by convention. They execute on Foundry's modified version of the EVM, which contains harness features like "off-chain" transaction signing and the ability to modify the source address of contract function calls.

(See [`/contracts/test/Tokin.t.sol`](../contracts/test/Tokin.t.sol)):

```bash
forge test -vvv # should be all green
```

## Create gas snapshot

```bash
forge snapshot # commit the resulting .gas-snapshot file
```

This command runs the test suite and logs the gas consumption for each test. It provides a record for the future detection of potentially costly performance regression due to refactors or dependency upgrades. Later, the `--check` and `--tolerance` flags (the latter for fuzz tests) can be used in CI jobs to ensure that unintended changes to the gas profile are caught prior to deployment.






