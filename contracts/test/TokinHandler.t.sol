// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Tokin} from "../src/Tokin.sol";

// Stateful handler of Tokin' calls for invariant testing
contract TokinHandler is Test {
    Tokin tokin;
    address[] public actors; // Tokin' holders
    mapping(address => bool) seen; // Membership guard to prevent duplication

    constructor(Tokin _t, address initialHolder) {
        tokin = _t;
        _register(initialHolder);
    }

    function _register(address a) internal {
        if (!seen[a]) {
            seen[a] = true;
            actors.push(a);
        }
    }

    function transfer(uint256 actorSeed, address to, uint256 amount) public {
        address from = actors[bound(actorSeed, 0, actors.length - 1)];
        amount = bound(amount, 0, tokin.balanceOf(from));
        vm.prank(from);
        // (See SafeERC20 documentation. It is overkill for a test suite.)
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        tokin.transfer(to, amount);
        _register(to);
    }

    function sumBalances() external view returns (uint256 total) {
        for (uint256 i; i < actors.length; i++) {
            total += tokin.balanceOf(actors[i]);
        }
        return total;
    }
}
