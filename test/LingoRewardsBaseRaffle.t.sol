// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LingoRewardsBaseRaffle} from "../src/LingoRewardsBaseRaffle.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {console} from "forge-std/console.sol";

contract LingoRewardsBaseRaffleTest is Test {
    LingoRewardsBaseRaffle lingoRewardsBaseRaffle;
    uint256 ownerPrivateKey;
    uint256 signerPrivateKey;
    address owner;
    address signer;
    address player1;
    address player2;

    function setUp() public {
        ownerPrivateKey = 1;
        signerPrivateKey = 1;
        owner = vm.addr(ownerPrivateKey);
        signer = vm.addr(signerPrivateKey);
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        vm.prank(owner);
        lingoRewardsBaseRaffle = new LingoRewardsBaseRaffle(owner, signer);
    }

    function testNewGame() public {
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Add assertions to check if the game was created correctly
        assertTrue(lingoRewardsBaseRaffle.getRaffleExists(randomnessCommitment));
        assertEq(lingoRewardsBaseRaffle.getCurrentRaffleId(), randomnessCommitment);
    }

    function testIncreasePlayerAmount() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Prepare signed data
        bytes32 gameId = randomnessCommitment;
        address account = player1;
        uint256 amount = 100;
        uint256 nonce = 0;

        bytes32 messageHash = keccak256(abi.encode(gameId, account, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);

        // Increase player amount
        lingoRewardsBaseRaffle.getRaffleTickets(
            gameId,
            account,
            amount,
            nonce,
            LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v}),
            keccak256("randomness")
        );

        // Add assertions to check if the player amount was increased correctly
        assertEq(lingoRewardsBaseRaffle.getPlayerAmount(player1), 100);
    }

    function testIncreasePlayerAmountZero() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Prepare signed data with zero amount
        bytes32 gameId = randomnessCommitment;
        address account = player1;
        uint256 amount = 0;
        uint256 nonce = 0;

        bytes32 messageHash = keccak256(abi.encode(gameId, account, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);

        // Increase player amount
        lingoRewardsBaseRaffle.getRaffleTickets(
            gameId,
            account,
            amount,
            nonce,
            LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v}),
            keccak256("randomness")
        );

        // Add assertions to check if the player amount was increased correctly
        assertEq(lingoRewardsBaseRaffle.getPlayerAmount(player1), 0);
    }

    function testIncreasePlayerAmountInvalidSignature() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Prepare data with invalid owner signature
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, player1, 100, 0));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, messageHash); // Using a different private key

        // Attempt to increase player amount with invalid signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignature.selector));
        lingoRewardsBaseRaffle.getRaffleTickets(
            randomnessCommitment,
            player1,
            100,
            0,
            LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v}),
            keccak256("randomness")
        );
    }

    function testGetWinner() public {
        bytes memory randomness = abi.encode("test");
        // Setup a new game and add players
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Add multiple players
        addPlayer(player1, 100);
        addPlayer(player2, 200);

        // Sign the randomness opening
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, randomness));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);

        // Get winner
        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(
            randomnessCommitment, randomness, LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v})
        );

        // Add assertions to check if a winner was selected correctly
        assertTrue(winner == player1 || winner == player2);
    }

    function testGetWinnerBoundaryValues() public {
        bytes memory randomness = abi.encode("test");
        // Setup a new game and add players
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Add multiple players
        addPlayer(player1, 100);
        addPlayer(player2, 200);

        // Sign the randomness opening
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, randomness));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);

        // Get winner with boundary values
        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(
            randomnessCommitment, randomness, LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v})
        );

        // Add assertions to check if a winner was selected correctly
        assertTrue(winner == player1 || winner == player2);
    }

    function testNewGameAlreadyExists() public {
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Attempt to create a game with the same randomnessCommitment
        vm.prank(owner);
        vm.expectRevert(LingoRewardsBaseRaffle.RaffleAlreadyExists.selector);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);
    }

    function testInvalidSignature() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Prepare data with invalid signature
        bytes32 gameId = randomnessCommitment;
        address account = player1;
        uint256 amount = 100;
        uint256 nonce = 0;
        LingoRewardsBaseRaffle.Signature memory invalidSignature =
            LingoRewardsBaseRaffle.Signature({r: bytes32(0), s: bytes32(0), v: 0});

        // Attempt to increase player amount with invalid signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignature.selector));
        lingoRewardsBaseRaffle.getRaffleTickets(
            gameId, account, amount, nonce, invalidSignature, keccak256("randomness")
        );
    }

    function testCommitmentAlreadyOpened() public {
        // Setup a new game and add players
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);
        addPlayer(player1, 100);

        // Sign the randomness opening
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, randomness));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);
        LingoRewardsBaseRaffle.Signature memory signature = LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v});

        // Get winner for the first time
        vm.prank(owner);
        lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness, signature);

        // Attempt to get winner for the second time
        vm.prank(owner);
        vm.expectRevert(LingoRewardsBaseRaffle.CommitmentAlreadyOpened.selector);
        lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness, signature);
    }

    function testInvalidRandomnessOpening() public {
        // Setup a new game and add players
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);
        addPlayer(player1, 100);

        bytes memory invalidRandomness = abi.encode("invalid");
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, invalidRandomness));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);
        LingoRewardsBaseRaffle.Signature memory signature = LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v});

        vm.expectRevert(LingoRewardsBaseRaffle.InvalidRandomnessOpening.selector);
        lingoRewardsBaseRaffle.getWinner(randomnessCommitment, invalidRandomness, signature);
    }

    function testReplayAttackSameGame() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Prepare signed data
        bytes32 gameId = randomnessCommitment;
        address account = player1;
        uint256 amount = 100;
        uint256 nonce = 0;

        bytes32 messageHash = keccak256(abi.encode(gameId, account, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);
        LingoRewardsBaseRaffle.Signature memory signature = LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v});

        // Increase player amount
        lingoRewardsBaseRaffle.getRaffleTickets(gameId, account, amount, nonce, signature, keccak256("randomness"));

        // Try to replay the same transaction in the same game
        vm.expectRevert(LingoRewardsBaseRaffle.InvalidNonce.selector);
        lingoRewardsBaseRaffle.getRaffleTickets(gameId, account, amount, nonce, signature, keccak256("randomness"));
    }

    function testReplayAttackDifferentGames() public {
        // Setup first game
        bytes32 randomnessCommitment1 = keccak256(abi.encode("test1"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment1);

        // Prepare signed data
        address account = player1;
        uint256 amount = 100;
        uint256 nonce = 0;

        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment1, account, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);
        LingoRewardsBaseRaffle.Signature memory signature = LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v});

        // Increase player amount in first game
        lingoRewardsBaseRaffle.getRaffleTickets(
            randomnessCommitment1, account, amount, nonce, signature, keccak256("randomness1")
        );

        // Setup second game
        bytes32 randomnessCommitment2 = keccak256(abi.encode("test2"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment2);

        // Try to replay the same transaction in the second game
        vm.expectRevert(abi.encodeWithSelector(LingoRewardsBaseRaffle.InvalidRaffleId.selector));
        lingoRewardsBaseRaffle.getRaffleTickets(
            randomnessCommitment1, account, amount, nonce, signature, keccak256("randomness2")
        );

        // Assert that the player amount was increased only in the first game
        assertEq(lingoRewardsBaseRaffle.getPlayerAmount(player1), 0);
    }

    // Helper function to add a player with a signed message
    function addPlayer(address player, uint256 amount) internal {
        bytes32 randomnessCommitment = lingoRewardsBaseRaffle.getCurrentRaffleId();
        uint256 nonce = 0;

        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, player, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);

        lingoRewardsBaseRaffle.getRaffleTickets(
            randomnessCommitment,
            player,
            amount,
            nonce,
            LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v}),
            keccak256("randomness")
        );
    }
}
