// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IRouter} from "./interface/aerodrome/IRouter.sol";

contract Souvenir is Script {
    function run() public {
        address tokinAddress = vm.envAddress("TOKIN_ADDRESS");
        address wethAddress = vm.envAddress("WETH_ADDRESS");
        IRouter router = IRouter(vm.envAddress("ROUTER_ADDRESS"));
        address poolFactoryAddress = vm.envAddress("POOL_FACTORY_ADDRESS");
        address recipient = vm.envAddress("SOUVENIR_RECIPIENT");
        uint256 purchaseAmount = 0.0002 ether;

        // NOTE: The IRouter.Route struct describes a single token-to-token swap through a specified pool.
        // In traditional market structure parlance, inherited by DeFi, "routing" is the act of composing
        // individual routes through multiple venues/liquidity sources. This use of the term is very confusing
        // when routing is treated as a network/graph optimisation problem, which is literally what DEX aggregators do.
        //
        // In any case, since the plan here is to acquire Tokin' in exchange for (W)ETH, only a single-hop
        // Route[] is required because these two tokens are how the one-and-only pool was seeded.
        IRouter.Route[] memory route = new IRouter.Route[](1);
        route[0] = IRouter.Route(wethAddress, tokinAddress, false, poolFactoryAddress);

        // Generate a "quote" for the swap route based on the current contents of the pool and the pool's swap fee.
        // The return value contains the input amount (in WETH) followed by expected Tokin' amount after every hop.
        uint256[] memory quote = router.getAmountsOut(purchaseAmount, route);
        require(quote[0] == purchaseAmount, "The route or the swap input is malformed");

        // Extract the expected Tokin' amount after the final (one and only) hop.
        uint256 expectedTokinAmount = quote[quote.length - 1];

        // Set a floor on the amount of slippage allowed for the swap in case the values shift due to
        // intermediate trades. In this case, 80% of the quoted amount (rounded down by truncation).
        uint256 minimumTokinOut = expectedTokinAmount * 80 / 100;

        vm.startBroadcast();

        // Execute the WETH -> Tokin' swap, and receive the *actual* amounts received per route hop.
        uint256[] memory swapAmounts = router.swapExactETHForTokens{
            // Buy a reasonably small portion of the supply (should be about ~4%)
            value: purchaseAmount
            }( //
                minimumTokinOut,
                // Route the swap through the WETH:Tokin' pool (there are no other options here)
                route,
                // Deliver the Tokin' to the designated souvenir recipient
                recipient,
                // Cap the amount of time the transaction can sit in mempools before being executed
                block.timestamp + 20 minutes
            );

        vm.stopBroadcast();

        // Extract the *actual* Tokin' amount received after the final (one and only) hop.
        uint256 received = swapAmounts[swapAmounts.length - 1];

        console.log("ETH spend:", purchaseAmount);
        console.log("Tokin' received:", received);
    }
}