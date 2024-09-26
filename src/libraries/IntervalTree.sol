// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library IntervalTree {
    struct Tree {
        address root;
        uint256 totalSum;
        mapping(address => Node) nodes;
    }

    struct Node {
        uint256 value;
        address left;
        uint256 leftSum;
        address right;
        uint256 rightSum;
    }

    function initialize(Tree storage self) internal {
        self.root = address(0x7fFFfFfFFFfFFFFfFffFfFfFfffFFfFfFffFFFFf);
        self.totalSum = 0;
    }

    function insert(Tree storage self, address account, uint256 amount) internal {
        address parent;
        address current = self.root;

        while (current != address(0)) {
            parent = current;

            if (parent == account) {
                break;
            } else if (parent > account) {
                self.nodes[parent].leftSum += amount;
                current = self.nodes[parent].left;
                if (current == address(0)) {
                    self.nodes[parent].left = account;
                }
            } else {
                self.nodes[parent].rightSum += amount;
                current = self.nodes[parent].right;
                if (current == address(0)) {
                    self.nodes[parent].right = account;
                }
            }
        }

        if (current == address(0)) {
            self.nodes[account].value = amount;
        } else {
            self.nodes[current].value += amount;
        }

        self.totalSum += amount;
    }

    function get(Tree storage self, address account) internal view returns (uint256) {
        address current = self.root;

        while (current != address(0)) {
            if (current == account) {
                return self.nodes[current].value;
            } else if (current > account) {
                current = self.nodes[current].left;
            } else {
                current = self.nodes[current].right;
            }
        }

        return 0; // Account not found
    }

    function getByPointOnInterval(Tree storage self, uint256 value) internal view returns (address) {
        address current = self.root;

        while (current != address(0)) {
            if (value < self.nodes[current].leftSum) {
                current = self.nodes[current].left;
            } else if (value < self.nodes[current].leftSum + self.nodes[current].value) {
                return current;
            } else {
                value -= self.nodes[current].leftSum + self.nodes[current].value;
                current = self.nodes[current].right;
            }
        }

        return address(0); // Point not found
    }
}
