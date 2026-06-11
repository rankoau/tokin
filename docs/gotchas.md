# Unexpected lessons learned

Here is a  list of interesting unforeseen nuances that are relevant to *any* token launch on an EVM blockchain.

## Base unit usage

There is a tendency for currency/token base units to be used interchangeably with their primary denomination. It can be especially confusing when trying to decipher the interface of a third party smart contract: it is often not entirely clear whether an *amount of ETH* is making reference to a number of Ether vs a number of Wei, and this is made trickier by the fact that Solidy provides syntactic sugar for literals that map to  integer values under the hood (e.g `0.005 ether`). On the other hand, meme coin and LP token amounts are only expressed in terms of their base units. It can be difficult to keep track of what all the enormous numbers mean.

You get used to it though:
- Any amount stored or transferred as `uint256` is almost certainly expressing currency/token base units.
- Both the tooling and the languages encourage thinking in scientific notation (e.g. a token supply is typically `1e27`, a modest amount of ETH in real-world terms is `1e15` Wei).

## Limited utility of testnets

One might imagine that testnets – in particular the Sepolia testnet operated alongside most EVM-compatible chain networks – to be indispensable for the staging of contract deployment and interaction. Surprisingly, this not the case for many projects.

The reason is that many projects interact with at least one smart contract that they do not control, and third party contract developers tend not to maintain testnet presences. In other words, assuming they exist on the chain's testnet in the first place, third party contracts are not guaranteed to be up-to-date, which means any validation made against their behaviour is potentially false.

Local forks of mainnet using tools like Foundry's `anvil` make for much more reliable staging environments despite only hosting single nodes, because they lazily load *real and current* contract bytecode. These setups are also CI-friendly.

That said, Sepolia testnets *are* a useful and/or necessary part of the testing strategy when:
- The project controls *all* of the smart contracts involved;
- Key parts of the staging environment consist of off-chain infrastructure.

## Explorer API keys

Conventional wisdom has it that all blockchain-related activity can be free if one accepts the trade-off of RPC provider rate limiting and occasional downtime. *This isn't **quite** the case any more (assuming it ever really was)*.

Block explorer API keys are required for certain tasks, such as fetching ABI definitions using `cast interface` or automating contract verification using `forge verify-contract`. More importantly, the management of those API keys was recently centralised by [etherscan.io](https://etherscan.io), and many chains, including Base, are only included in paid subscriptions starting at $49/mo (USD).

Workarounds remain in every case I came across, but some of them are manual.

## Source code verification

Publishing and verifying source code against its resulting EVM bytecode is not simply a trust-maximising nice-to-have, it is in fact *essential* to avoid being flagged as a potential honeypot *by default*, because bytecode decompilation cannot always clarify the presence or otherwise of backdoor minting methods, sell-blocking logic, and probably a whole range of similarly malicious implementation details.

## Metadata isolation

A token can be launched, and its accompanying metadata, logo and website can be live, but *no link* between the two ever exists on the blockchain. In other words, tokens do not contain a reference to their metadata.

Instead, every single part of the ecosystem must define *its own* linkage. This makes the overall user experience very poor, or indeed a complete non-event. A high amount of effort on the developer's part is required to give a token an actual usable presence in places like wallets and swap venues, and this effort is often taken to be part-and-parcel with actual promotional activity, otherwise in some places it tends to get rejected. Obscurity is generally associated with danger.

## Wallet suppression

Even when a user *holds the token*, every wallet app applies slightly different policies with respect to suppressing it. Tokin' didn't appear *at all* in MetaMask or Exodus without explicitly importing the token address. Phantom identified its existence, but required it to be enabled in an out-of-the-way menu first. Both surround the token with scary-sounding warnings. Unlike in some DEX UIs, there appears to be no way for an individual user to link metadata to make the logo appear.

(These are sensible policies of course, since a wallet cannot distinguish between a genuine peer-to-peer transfer and an airdrop as part of a scam)

## Key differences from a [Solana meme coin launch](https://github.com/rankoau/obstok/blob/main/docs/runsheet.md)

- More code gets written, but not as part of the ERC-20 token itself, whose implementations have become standardised and extensively battle-tested. It's the *scripts* executed by `forge` on a local EVM to safely transact on the blockchain without having to do things like express selectors as strings or worry about numeric type conversion.

- Since, to use Token-2022 on Solana, no new bytecode gets deployed *at all*, there is no extra scrutiny by honeypot detectors and no source code to independently verify. By contract, even though pure meme coin ERC-20 contracts are trivial, a much higher level of automated scrutiny applies, and it requires more work to get over these hurdles.

- Whereas Solana currencies and tokens tend to be either 6 or 9 decimal places beyond their primary denomination, on EVM it is standard for tokens to have 18. It is easy to misread such long numbers, and reasoning about them can be mentally taxing.

- The concept of renouncing token mint/burn/freeze authorities doesn't exist. Instead, ERC-20 contracts can be deployed that never contain such privileged actions in the first place. Token-2022 *needs* this flexibility to cater for a wide variety of tokens using a single program.

- Token-2022's on-chain metadata extension has no ERC-20 equivalent. In particular, logos for Solana tokens are accessible and usually rendered by all wallets and relevant websites, whereas for ERC-20 tokens this is a major headache (see previous point abount metadata isolation).

- Raydium's DEX design is decidedly more complex than that of Aerodrome or Uniswap v2. Practically speaking, this means that is viable to script the setup of a liquidity pool on the latter, where on Raydium a pool can only easily be setup through the UI. Additionally, in the Uniswap v2 model, the LP token and the pool itself are implemented by the *same contract* – and the LP token is an ERC-20 like any other.

- On Raydium, liquidity injection incurs a fee, while on Aerodrome, it does not. Conversely, Aerodrome charges *swap fees* that are built into the routing prices.

- On Solana, burning tokens using Token2022's `burn` function is considered to be in some sense more correct than sending them to the canonical `incinerator` address. On EVM chains, sending to the `0x00...dEaD` address is very much the communal expectation.

- Unlike OBSTOK on Solana, TOKIN on Base didn't get "nibbled" by multiple trading bots trying to identify an early price trend. This is probably because the bulk of the meme-coin community migrated from Ethereum to Solana several years ago, and the bots were set up accordingly. Solana is also a significant L1 chain, whereas Base is just one of many established L2 rollup chains.