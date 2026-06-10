// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Tokin is ERC20, ERC20Permit {
    constructor(address deployer)
        ERC20("Tokin'", "TOKIN") // Call ERC20's constructor with name and symbol
        ERC20Permit("Tokin'") // Call ERC20Permit's constructor with the name

    {
        _mint(deployer, 1_000_000_000 * 10 ** decimals());
    }
}
