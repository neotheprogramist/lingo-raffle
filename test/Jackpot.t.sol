// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Jackpot.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {console} from "forge-std/console.sol";

contract JackpotTest is Test {
    Jackpot jackpot;
    uint256 ownerPrivateKey;
    address owner;
    address player1;
    address player2;

    function setUp() public {
        ownerPrivateKey = 1;
        owner = vm.addr(ownerPrivateKey);
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        vm.prank(owner);
        jackpot = new Jackpot(owner);
    }

    function testNewGame() public {
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);

        // Add assertions to check if the game was created correctly
        assertTrue(jackpot.getGameExists(randomnessCommitment));
        assertEq(jackpot.getCurrentGameId(), randomnessCommitment);
    }

    function testIncreasePlayerAmount() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);

        // Prepare signed data
        Jackpot.IncreasePlayerAmountData memory data = Jackpot.IncreasePlayerAmountData({
            account: player1,
            amount: 100,
            signature: Jackpot.Signature({r: bytes32(0), s: bytes32(0), v: 0})
        });

        bytes32 messageHash = keccak256(abi.encode(data.account, data.amount));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);
        data.signature = Jackpot.Signature({r: r, s: s, v: v});

        // Increase player amount
        jackpot.increasePlayerAmount(data, keccak256("randomness"));

        // Add assertions to check if the player amount was increased correctly
        assertEq(jackpot.getPlayerAmount(player1), 100);
    }

    function testGetWinner() public {
        bytes memory randomness = abi.encode("test");
        // Setup a new game and add players
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);

        // Add multiple players
        addPlayer(player1, 100);
        addPlayer(player2, 200);

        // Get winner
        vm.prank(owner);
        address winner = jackpot.getWinner(randomness);

        // Add assertions to check if a winner was selected correctly
        assertTrue(winner == player1 || winner == player2);
    }

    function testNewGameAlreadyExists() public {
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);

        // Attempt to create a game with the same randomnessCommitment
        vm.prank(owner);
        vm.expectRevert(Jackpot.GameAlreadyExists.selector);
        jackpot.newGame(randomnessCommitment);
    }

    function testInvalidSignature() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);

        // Prepare data with invalid signature
        Jackpot.IncreasePlayerAmountData memory data = Jackpot.IncreasePlayerAmountData({
            account: player1,
            amount: 100,
            signature: Jackpot.Signature({r: bytes32(0), s: bytes32(0), v: 0})
        });

        // Attempt to increase player amount with invalid signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignature.selector));
        jackpot.increasePlayerAmount(data, keccak256("randomness"));
    }

    function testCommitmentAlreadyOpened() public {
        // Setup a new game and add players
        bytes memory randomnessOpening = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomnessOpening);
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);
        addPlayer(player1, 100);

        // Get winner for the first time
        vm.prank(owner);
        jackpot.getWinner(randomnessOpening);

        // Attempt to get winner for the second time
        vm.prank(owner);
        vm.expectRevert(Jackpot.CommitmentAlreadyOpened.selector);
        jackpot.getWinner(randomnessOpening);
    }

    function testInvalidRandomnessOpening() public {
        // Setup a new game and add players
        bytes memory randomnessOpening = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomnessOpening);
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);
        addPlayer(player1, 100);

        bytes memory invalidRandomnessOpening = abi.encode("invalid");
        vm.expectRevert(Jackpot.InvalidRandomnessOpening.selector);
        jackpot.getWinner(invalidRandomnessOpening);
    }

    // Helper function to add a player with a signed message
    function addPlayer(address player, uint256 amount) internal {
        Jackpot.IncreasePlayerAmountData memory data = Jackpot.IncreasePlayerAmountData({
            account: player,
            amount: amount,
            signature: Jackpot.Signature({r: bytes32(0), s: bytes32(0), v: 0})
        });

        bytes32 messageHash = keccak256(abi.encode(data.account, data.amount));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);
        data.signature = Jackpot.Signature({r: r, s: s, v: v});

        jackpot.increasePlayerAmount(data, keccak256("randomness"));
    }
}
