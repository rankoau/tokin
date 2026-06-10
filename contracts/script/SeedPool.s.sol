// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Tokin} from "../src/Tokin.sol";
import {IPoolFactory} from "./interface/aerodrome/IPoolFactory.sol";
import {IRouter} from "./interface/aerodrome/IRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SeedPool is Script {
    function run() public {
        Tokin tokin = Tokin(vm.envAddress("TOKIN_ADDRESS"));
        IERC20 weth = IERC20(vm.envAddress("WETH_ADDRESS"));
        IPoolFactory poolFactory = IPoolFactory(vm.envAddress("POOL_FACTORY_ADDRESS"));
        IRouter router = IRouter(vm.envAddress("ROUTER_ADDRESS"));
        address deployer = msg.sender;

        uint256 etherDeposit = 0.005 ether;
        require(deployer.balance >= etherDeposit, "Insufficient ETH to seed liquidity with");

        uint256 tokinBalance = tokin.balanceOf(deployer);
        require(tokinBalance > 0, "Insufficient Tokin' to seed liquidity with");

        vm.startBroadcast();

        // Approve the Aerodrome router to `transferFrom` the full Tokin' balance
        bool approved = tokin.approve(address(router), tokinBalance);
        require(approved, "Failed to approve Tokin' -> Router transfer");

        // Create and seed the (W)ETH:TOKIN liquidity pool, returning LP tokens to the deployer.
        // NOTE: the interface return value documentation is misleading. In this case they should be read as:
        // `amountToken`: the amount of Tokin' that *was* actually deposited;
        // `amountWETH`: the amount of *Wrapped Ether (WETH)* that *was* actually deposited;
        // `liquidity`: the amount of LP token that was returned to the deployer.
        (uint256 amountToken, uint256 amountWETH, uint256 liquidity) = router.addLiquidityETH{
            // Send the desired amount of ETH for depositing in the pool (not including gas fees).
            value: etherDeposit
        }( // The blockchain address of the Tokin' contract.
            address(tokin),
            // Specifies a volatile pool governed by the Uniswap v2 x*y=k curve.
            false,
            // Specify the amount of Tokin' to deposit in the pool (the full approved balance).
            tokinBalance,
            // The Tokin' "slippage guard": the call reverts if fewer than this many tokens would be actually added to the pool.
            // None is needed on the first liquidity addition; nonzero values make sense for subsequent additions.
            0,
            // The ETH "slippage guard": the call reverts if fewer than this amount of ETH would be actually added to the pool.
            // None is needed on the first liquidity addition; nonzero values make sense for subsequent additions.
            0,
            // The recipient of the liquidity token which gets minted upon successful pool creation.
            deployer,
            // Cap the amount of time the transaction can sit in mempools before being executed.
            block.timestamp + 20 minutes
        );

        vm.stopBroadcast();

        // In the Aerodrome/Uniswap v2 paradigm, the Pool contract is both an AMM *and* an ERC-20 token.
        // The token being tracked is the representation of the liquidity provider's shares in the pool.
        // This address is subsequently used to perform the token burn in BurnLP.s.sol.
        address poolAddress = poolFactory.getPool(address(tokin), address(weth), false);
        require(IERC20(poolAddress).balanceOf(deployer) == liquidity, "LP balance mismatch");

        console.log("Pool / LP token address:", poolAddress);
        console.log("TOKIN' deposited:", amountToken);
        console.log("WETH deposited:", amountWETH);
        console.log("LP minted to deployer:", liquidity);
    }
}
