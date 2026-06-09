// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
 
import {Script, console} from "forge-std/Script.sol";
import {Tokin} from "../src/Tokin.sol";
 
contract SeedPool is Script {

    function run() public {

        IPoolFactory poolFactory = IPoolFactory(vm.envAddress("POOL_FACTORY_ADDRESS"));

        vm.startBroadcast();
        
        
        
        vm.stopBroadcast();
    }

}