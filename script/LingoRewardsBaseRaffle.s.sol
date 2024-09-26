// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LingoRewardsBaseRaffle} from "../src/LingoRewardsBaseRaffle.sol";

contract LingoRewardsBaseRaffleScript is Script {
    LingoRewardsBaseRaffle public lingoRewardsBaseRaffle;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        lingoRewardsBaseRaffle = new LingoRewardsBaseRaffle(msg.sender, msg.sender);

        vm.stopBroadcast();
    }
}
