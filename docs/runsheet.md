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

Install the latest OpenZeppelin contract collection as a additional dependency alongside the forge standard library:

```bash
cd contracts
forge install OpenZeppelin/openzeppelin-contracts@v5.6.1
```

Write an explicit `remappings.txt` to ensure that both `forge` and IDE plugins understand `@openzeppelin/*` import paths:

```bash
forge remappings > remappings.txt
```

Update the default `foundry.toml` configuration to explicitly set the Solidy compiler version and avoid a bunch of deprecation warnings:

```bash
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.26"
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

## Configure RPC provider endpoints

In `contracts/foundry.toml`, set the URLs of the public Base `mainnet` and `testnet` JSON-RPC endpoints. These are free and require zero setup. They are also rate-limited and occasionally flaky.

```bash
[rpc_endpoints]
base = "https://mainnet.base.org"
base_sepolia = "https://sepolia.base.org"
local = "http://127.0.0.1:8545"
```

> [!NOTE]
> This setting is read by the `forge` and `cast` commands, but it is **not** read by `anvil`.

## Configure Basescan endpoints

TODO: Get a basescan.io API key...

In `contracts/foundry.toml` ...

```bash
[etherscan]
base         = { key = "${BASESCAN_API_KEY}", chain = 8453 }
base_sepolia = { key = "${BASESCAN_API_KEY}", chain = 84532 }
```

## Write deployment scripts

There are plenty of ways to actually transact on EVM blockchains, but the most convenient and type-safe is to use Foundry's own scripting setup. The code is executed on an equivalent virtual machine to that of the destination blockchain itself.

For a meme coin deployment there are three short scripts needed:

1. [`/contracts/script/Deploy.s.sol`](../contracts/script/Deploy.s.sol) to create the token contract
2. [`/contracts/script/SeedPool.s.sol`](../contracts/script/SeedPool.s.sol) to setup the liquidity pool on Aerodrome
3. [`/contracts/script/BurnLP.s.sol`](../contracts/script/BurnLP.s.sol) to burn the liquidity provider tokens (making a "rug pull" impossible)

**(1)** simply creates the token and logs its address. **(3)** Relies on the fact that the liquidity provider tokens are *also* ERC-20 tokens, whose interface is already installed as part of the OpenZeppelin library. **(2)** Requires *just the interfaces* for the relevant Aerodrome smart contracts, which `cast` can generate from ABI definitions fetched from the official source:

```bash
cast interface 0x420DD381b31aEf6683db6B902084cB0FFECe40Da --chain base --etherscan-api-key $BASESCAN_API_KEY -o script/interfaces/IPoolFactory.sol
```

## Configure deployer wallets

### local

Use the standard key for Anvil's account `0` (it is the same for everybody's instance of Anvil):

```bash
cast wallet import tokin-local --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

The `import` command above creates a `tokin-local` keystore file in `~/.foundry/keystores/`, which is used later by `forge script`'s `--account` option to determine which address to use as the deployer.

> [!WARNING]
> The `--private-key` option is only suitable for local testing using publicly-known private keys like this.

### testnet

Create a dedicated key pair for deployment on the Sepolia testnet:

```bash
cast wallet new ~/.foundry/keystores tokin-testnet
```

### mainnet

Create a dedicated key pair for deployment on the Base mainnet:

```bash
cast wallet new ~/.foundry/keystores tokin-mainnet
```

Verify the setup:

```bash
cast wallet list
# 0xtokin-local (Local)
# 0xtokin-mainnet (Local)
# 0xtokin-testnet (Local)
```

## Spin up a local blockchain fork

```bash
anvil --fork-url https://mainnet.base.org --chain-id 8453
```

This command launches a single-node instance of the Base network. The local chain's genesis block is "pinned" to the most recent block on the real blockchain. It then forwards state reads to the remote RPC and caches them locally; new transactions build on top without ever touching the real network.

A couple of sense checks once it's running:

```bash
cast chain-id --rpc-url local # should return the Base chain ID of 8453
cast block-number # should return the latest block number
```

Compare the output of the second command to the block number reported by https://basescan.org/. Base produces new blocks every 2 seconds.

## Perform a local dry run

Run the three scripts in sequence to simulate the complete launch against the local Anvil instance:

```bash
forge script script/Deploy.s.sol --rpc-url local --broadcast --account tokin-local --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

(In this case the sender is the standard public address for Anvil account `0`)

> [!TIP]
> `forge` will fail if `--sender` and `--account` do not produce a matching keypair. If `--sender` is omitted it will first decrypt the account file to derive the public key; however, being explicit is a guardrail to reduce the likelihood of accidentally transacting from the wrong address.

Note the `console.log` output containing the address of the deployed token contract:

```bash
== Logs ==
Tokin deployed at: 0x...
```

This value is needed for the following scripts.