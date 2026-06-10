// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BurnLP is Script {
    using SafeERC20 for IERC20;

    function run() public {
        IERC20 lpToken = IERC20(vm.envAddress("LP_TOKEN_ADDRESS"));
        address deployer = msg.sender;
        address burnAddress = 0x000000000000000000000000000000000000dEaD;
        uint256 lpTokenBalance = lpToken.balanceOf(deployer);

        require(lpTokenBalance > 0, "No LP Tokens to burn");

        vm.startBroadcast();
        // Use a SafeERC20 transfer instead of a straight IERC20 transfer,
        // so that false return values are as treated as errors and correctly revert.
        lpToken.safeTransfer(burnAddress, lpTokenBalance);
        vm.stopBroadcast();

        require(lpToken.balanceOf(deployer) == 0, "Burn incomplete");

        console.log("Burned LP amount:", lpTokenBalance);
        console.log("Deployer LP remaining:", lpToken.balanceOf(deployer));
        console.log("Burn address LP held:", lpToken.balanceOf(burnAddress));
    }
}
