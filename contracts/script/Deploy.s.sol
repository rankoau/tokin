// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
 
import {Script, console} from "forge-std/Script.sol";
import {Tokin} from "../src/Tokin.sol";
 
contract Deploy is Script {

    function run() public {
        vm.startBroadcast();
        
        Tokin token = new Tokin(msg.sender);
        console.log("Tokin deployed at:", address(token));
        
        vm.stopBroadcast();
    }

}