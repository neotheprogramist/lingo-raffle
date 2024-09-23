// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IntervalTree} from "../src/libraries/IntervalTree.sol";

contract IntervalTreeTest is Test {
    using IntervalTree for IntervalTree.Tree;

    IntervalTree.Tree private tree;
    uint256 constant MAX_VALUE = 1_000_000_000_000_000_000;

    mapping(address => uint256) private occurrences;
    mapping(address => uint256) private cumulativeValues;

    function setUp() public {
        tree.initialize();
    }

    function testFuzzInsertAndGet(address account, uint256 value) public {
        // Ensure account is non-zero and value is within bounds
        vm.assume(account != address(0));
        value = bound(value, 1, MAX_VALUE);

        // Insert value and check if it is stored correctly
        tree.insert(account, value);
        assertEq(tree.get(account), value);
    }

    function testFuzzGetByPointOnInterval(address[30] memory accounts, uint8[50] memory values) public {
        // Ensure all accounts are non-zero
        for (uint256 i = 0; i < accounts.length; i++) {
            vm.assume(accounts[i] != address(0));
        }

        uint256 sum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            address account = accounts[uint256(keccak256(abi.encodePacked(values[i]))) % accounts.length];
            cumulativeValues[account] += values[i];
            tree.insert(account, values[i]);
            sum += values[i];
        }

        // Check if getByPointOnInterval returns correct accounts
        for (uint256 i = 0; i < sum; i++) {
            address acc = tree.getByPointOnInterval(i);
            occurrences[acc]++;
        }

        // Verify occurrences match cumulative values
        for (uint256 i = 0; i < accounts.length; i++) {
            assertEq(occurrences[accounts[i]], cumulativeValues[accounts[i]]);
        }
    }

    function testFuzzClear(address[30] memory accounts, uint8[50] memory values) public {
        // Ensure all accounts are non-zero
        for (uint256 i = 0; i < accounts.length; i++) {
            vm.assume(accounts[i] != address(0));
        }

        // Insert values into the tree
        for (uint256 i = 0; i < values.length; i++) {
            address account = accounts[uint256(keccak256(abi.encodePacked(values[i]))) % accounts.length];
            tree.insert(account, values[i]);
        }

        // Clear the tree and verify all values are reset
        tree.clear();

        for (uint256 i = 0; i < accounts.length; i++) {
            assertEq(tree.get(accounts[i]), 0);
        }
        assertEq(tree.totalSum, 0);
    }

    function testFuzzInsertExistingAccount(address account, uint8[50] memory values) public {
        // Ensure account is non-zero
        vm.assume(account != address(0));

        uint256 sum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            tree.insert(account, values[i]);
            sum += values[i];
        }

        // Verify the total value for the account
        assertEq(tree.get(account), sum);
    }

    function testFuzzGetNonExistentAccount(address account) public view {
        // Ensure account is non-zero
        vm.assume(account != address(0));

        // Verify the value for a non-existent account is zero
        assertEq(tree.get(account), 0);
    }
}
