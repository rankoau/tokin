// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Tokin} from "../src/Tokin.sol";

contract Deploy is Script {
    function run() public {
        address deployer = msg.sender;

        vm.startBroadcast();

        Tokin tokin = new Tokin(deployer);
        console.log("Tokin' deployed at:", address(tokin));

        vm.stopBroadcast();
    }
}
