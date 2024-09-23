// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Jackpot} from "../src/Jackpot.sol";

contract JackpotScript is Script {
    Jackpot public jackpot;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        jackpot = new Jackpot(msg.sender);

        vm.stopBroadcast();
    }
}
