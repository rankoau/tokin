// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
 
import {Script, console} from "forge-std/Script.sol";
import {Tokin} from "../src/Tokin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
 
contract BurnLP is Script {

    function run() public {
        Tokin token = Tokin(vm.envAddress("TOKIN_ADDRESS"));
        IERC20 lpToken = IERC20(vm.envAddress("LP_TOKEN_ADDRESS"));
        address deployer = msg.sender;
        address burnAddress = 0x000000000000000000000000000000000000dEaD;
        uint256 lpTokenBalance = lpToken.balanceOf(msg.sender);

        require(lpTokenBalance > 0, "No LP Tokens to burn");

        vm.startBroadcast();
        token.transfer(burnAddress, lpTokenBalance);
        vm.stopBroadcast();

        console.log("Burned LP amount:", lpTokenBalance);
        console.log("Deployer LP remaining:", lpToken.balanceOf(deployer));
        console.log("Burn address LP held:", lpToken.balanceOf(burnAddress));
    }

}