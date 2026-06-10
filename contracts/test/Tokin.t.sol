// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {TokinHandler} from "./TokinHandler.t.sol";
import {Tokin} from "../src/Tokin.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// (See the SafeERC20 documentation. It is overkill for a test suite.)
// forge-lint: disable-next-item(erc20-unchecked-transfer)
contract TokinTest is Test {
    Tokin tokin;
    TokinHandler tokinHandler;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol;
    uint256 carolPrivateKey;

    // Create and mint the supply of Tokin'
    function setUp() public {
        tokin = new Tokin(deployer);
        (carol, carolPrivateKey) = makeAddrAndKey("permitOwner");

        // Invariant testing setup
        tokinHandler = new TokinHandler(tokin, deployer);
        targetContract(address(tokinHandler));
    }

    // The full supply should be 1 Billion * 10^18 wei
    function test_TotalSupply() public view {
        assertEq(tokin.totalSupply(), 1e27);
    }

    // Transfering an amount of the token preserves the fixed supply
    // (Note that the fuzzer biases towards boundaries to ensure edge case coverage)
    /// forge-config: default.fuzz.runs = 10000
    function testFuzz_TransferPreservesSupply(uint256 amount) public {
        amount = bound(amount, 0, tokin.balanceOf(deployer));
        vm.prank(deployer);
        tokin.transfer(bob, amount);
        assertEq(tokin.totalSupply(), 1e27);
    }

    // The deployer's account should have the full supply of tokens minted into it
    function test_DeployerGetsFullSupply() public view {
        assertEq(tokin.balanceOf(deployer), tokin.totalSupply());
    }

    // Test the transfer of 5M Tokin' from the deployer to Bob
    function test_Transfer() public {
        uint256 amount = 5_000_000 * 10 ** tokin.decimals();

        // Since the test suite is a contract, token.transfer would otherwise be a contract -> contract call.
        // vm.prank is Foundry's EVM interceptor that simulates a call a specific address instead, by overriding msg.sender.
        vm.prank(deployer);
        tokin.transfer(bob, amount);

        assertEq(tokin.balanceOf(bob), amount);
    }

    // Test on-chain approval (set up an allowance, enable deduction from the owner's balance by the approved spender)
    function test_ApproveTransferFrom() public {
        uint256 amount = 5_000_000 * 10 ** tokin.decimals();

        vm.prank(deployer);
        tokin.transfer(alice, amount);

        vm.prank(alice);
        tokin.approve(bob, amount);
        assertEq(tokin.allowance(alice, bob), amount);

        vm.prank(bob);
        tokin.transferFrom(alice, bob, amount);
        assertEq(tokin.balanceOf(bob), amount);
        assertEq(tokin.balanceOf(alice), 0);
    }

    // Test the owner approving more than their actual account balance
    function test_ApprovalBeyondBalance() public {
        uint256 balance = 5_000_000 * 10 ** tokin.decimals();
        uint256 approvedAmount = 10_000_000 * 10 ** tokin.decimals();

        vm.prank(deployer);
        tokin.transfer(alice, balance);

        vm.prank(alice);
        tokin.approve(bob, approvedAmount);
        assertEq(tokin.allowance(alice, bob), approvedAmount);

        vm.prank(bob);
        bytes memory revertData =
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, balance, approvedAmount);
        vm.expectRevert(revertData);
        tokin.transferFrom(alice, bob, approvedAmount);

        assertEq(tokin.balanceOf(alice), balance);
    }

    // Test that an approved spender cannot withdraw more than the approved amount,
    // even if the owner has sufficient funds available
    function test_ApprovedTransferOverdraw() public {
        uint256 balance = 10_000_000 * 10 ** tokin.decimals();
        uint256 approvedAmount = 5_000_000 * 10 ** tokin.decimals();

        vm.prank(deployer);
        tokin.transfer(alice, balance);

        vm.prank(alice);
        tokin.approve(bob, approvedAmount);
        assertEq(tokin.allowance(alice, bob), approvedAmount);

        vm.prank(bob);
        bytes memory revertData =
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, approvedAmount, balance);
        vm.expectRevert(revertData);
        tokin.transferFrom(alice, bob, balance);

        assertEq(tokin.balanceOf(alice), balance);
    }

    // Construct a valid signed approval (permit) transaction "off-chain" (compare `test_PermitInvalidSigner`)
    function _offchainSignedTransaction(uint256 value, uint256 deadline, uint256 nonce)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        // EIP-712 hash of the message *type*, allowing .permit() to reconstruct the digest and prove
        // that the call could not have been destined for somewhere else expecting the same field layout.
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        // Hash of the permit type signature and its arguments
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, carol, bob, value, nonce, deadline));

        // The domain separator is a quasi-constant exposed by ERC20Permit which ensures
        // the digest is unique to a given version of the contract on a given chain.
        // \x19\x01 is the mandatory EIP-712 prefix binding the struct hash to the domain.
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", tokin.DOMAIN_SEPARATOR(), structHash));

        // Sign the transaction, returning ECDSA signature components:
        // (r, s) is the signature, v is the recovery id (27/28)
        return vm.sign(carolPrivateKey, digest);
    }

    // Test off-chain approval (EIP-2612)
    function test_Permit() public {
        uint256 value = 5_000_000 * 10 ** tokin.decimals();
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tokin.nonces(carol); // ERC-2612's method of checking the owner's current nonce

        (uint8 v, bytes32 r, bytes32 s) = _offchainSignedTransaction(value, deadline, nonce);

        // Authorization comes from the signature, not msg.sender. Anyone can submit it.
        // (note the lack of vm.prank)
        tokin.permit(carol, bob, value, deadline, v, r, s);

        assertEq(tokin.allowance(carol, bob), value);
        assertEq(tokin.nonces(carol), nonce + 1);
    }

    // Test off-chain approval expiry (EIP-2612)
    function test_PermitExpiry() public {
        uint256 value = 5_000_000 * 10 ** tokin.decimals();
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tokin.nonces(carol); // ERC-2612's method of checking the owner's current nonce

        (uint8 v, bytes32 r, bytes32 s) = _offchainSignedTransaction(value, deadline, nonce);

        // Fast-forward the vm's block time past the deadline, then attempt permit execution
        vm.warp(block.timestamp + 2 hours);
        bytes memory revertData = abi.encodeWithSelector(ERC20Permit.ERC2612ExpiredSignature.selector, deadline);
        vm.expectRevert(revertData);
        tokin.permit(carol, bob, value, deadline, v, r, s);

        assertEq(tokin.allowance(carol, bob), 0);

        // Unlike a transaction nonce, replay attack prevention for EIP-2612 transactions
        // requires this nonce to *not* increment
        assertEq(tokin.nonces(carol), nonce);
    }

    // Test that a permit is rejected unless signed by the owner themselves (forgery protection)
    function test_PermitInvalidSigner() public {
        uint256 value = 5_000_000 * 10 ** tokin.decimals();
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tokin.nonces(carol);

        (address attacker, uint256 attackerPrivateKey) = makeAddrAndKey("attacker");

        // Build carol's permit digest (owner == carol).
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, carol, bob, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", tokin.DOMAIN_SEPARATOR(), structHash));

        // Sign carol's digest with the attacker's key.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attackerPrivateKey, digest);

        // The error reports (recovered signer, expected owner) == (attacker, carol).
        bytes memory revertData = abi.encodeWithSelector(ERC20Permit.ERC2612InvalidSigner.selector, attacker, carol);

        // ecrecover inside permit will recover `attacker`, not carol, and the owner mismatch is rejected.
        vm.expectRevert(revertData);
        tokin.permit(carol, bob, value, deadline, v, r, s);

        // Assert no side effects
        assertEq(tokin.allowance(carol, bob), 0);
        assertEq(tokin.nonces(carol), nonce);
    }

    function _selectorExists(string memory sig, bytes memory args) internal returns (bool ok) {
        (ok,) = address(tokin).call(bytes.concat(abi.encodeWithSignature(sig), args));
    }

    // Reduce the likelihood of mint funtionality being added in later refactors by failing on common selectors
    function test_NoExternalMintSelectors() public {
        assertFalse(_selectorExists("mint(uint256)", abi.encode(1e18)));
        assertFalse(_selectorExists("mint(address,uint256)", abi.encode(alice, 1e18)));
        assertFalse(_selectorExists("issue(uint256)", abi.encode(1e18)));
        assertFalse(_selectorExists("issue(address,uint256)", abi.encode(alice, 1e18)));
    }

    // Verify that no sequence of calls can alter the total supply
    function invariant_supplyConstant() public view {
        assertEq(tokin.totalSupply(), 1e27);
    }

    // Verify that no sequence of calls can causes the sum of holder balances to drift from the total supply
    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_balancesSumToSupply() public view {
        assertEq(tokinHandler.sumBalances(), tokin.totalSupply());
    }
}

