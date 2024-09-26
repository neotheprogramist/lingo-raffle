// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LingoRewardsBaseRaffle} from "../src/LingoRewardsBaseRaffle.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
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
    mapping(address => uint256) private playerNonces;

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

        // Get winner
        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

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

        // Get winner with boundary values
        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

        // Add assertions to check if a winner was selected correctly
        assertTrue(winner == player1 || winner == player2);
    }

    function testNewGameAlreadyExists() public {
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);
        vm.prank(owner);
        lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

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

        // Get winner for the first time
        vm.prank(owner);
        lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

        // Attempt to get winner for the second time
        vm.prank(owner);
        vm.expectRevert(LingoRewardsBaseRaffle.CommitmentAlreadyOpened.selector);
        lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);
    }

    function testInvalidRandomnessOpening() public {
        // Setup a new game and add players
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);
        addPlayer(player1, 100);

        bytes memory invalidRandomness = abi.encode("invalid");

        vm.prank(owner);
        vm.expectRevert(LingoRewardsBaseRaffle.InvalidRandomnessOpening.selector);
        lingoRewardsBaseRaffle.getWinner(randomnessCommitment, invalidRandomness);
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
        bytes memory randomness = abi.encode("test1");
        bytes32 randomnessCommitment1 = keccak256(randomness);
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

        vm.prank(owner);
        lingoRewardsBaseRaffle.getWinner(randomnessCommitment1, randomness);

        // Setup second game
        bytes32 randomnessCommitment2 = keccak256(abi.encode("test2"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment2);
        //dodać zamknięcie raffla
        // Try to replay the same transaction in the second game
        vm.expectRevert(abi.encodeWithSelector(LingoRewardsBaseRaffle.InvalidRaffleId.selector));
        lingoRewardsBaseRaffle.getRaffleTickets(
            randomnessCommitment1, account, amount, nonce, signature, keccak256("randomness1")
        );

        // Assert that the player amount was increased only in the first game
        assertEq(lingoRewardsBaseRaffle.getPlayerAmount(player1), 0);
    }

    function testSetSigner() public {
        uint256 newSignerPrivateKey = 3;
        address newSigner = vm.addr(newSignerPrivateKey);
        vm.prank(owner);
        lingoRewardsBaseRaffle.setSigner(newSigner);

        // Prepare signed data with new signer
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, player1, 100, 0));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(newSignerPrivateKey, messageHash);

        // Increase player amount with new signer
        lingoRewardsBaseRaffle.getRaffleTickets(
            randomnessCommitment,
            player1,
            100,
            0,
            LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v}),
            keccak256("randomness")
        );

        // Assert that the player amount was increased correctly
        assertEq(lingoRewardsBaseRaffle.getPlayerAmount(player1), 100);
    }

    function testPauseAndUnpause() public {
        vm.prank(owner);
        lingoRewardsBaseRaffle.pause();

        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        vm.prank(owner);
        lingoRewardsBaseRaffle.unpause();

        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);
        assertTrue(lingoRewardsBaseRaffle.getRaffleExists(randomnessCommitment));
    }

    function testGetRaffleDetails() public {
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        assertEq(lingoRewardsBaseRaffle.getRaffleRandomnessCommitment(randomnessCommitment), randomnessCommitment);
        assertEq(lingoRewardsBaseRaffle.getRaffleCurrentRandomness(randomnessCommitment), randomnessCommitment);
        assertFalse(lingoRewardsBaseRaffle.getRaffleCommitmentOpened(randomnessCommitment));
        assertTrue(lingoRewardsBaseRaffle.getRaffleExists(randomnessCommitment));
    }

    function testGetWinnerWithNoPlayers() public {
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

        assertEq(winner, address(0));
    }

    function testMultiplePlayersWithDifferentAmounts() public {
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        address player3 = makeAddr("player3");
        address player4 = makeAddr("player4");

        addPlayer(player1, 100);
        addPlayer(player2, 200);
        addPlayer(player3, 50);
        addPlayer(player4, 150);

        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

        assertTrue(winner == player1 || winner == player2 || winner == player3 || winner == player4);
    }

    function testBenchmarkManyUsers() public {
        uint256 seed = 0;
        uint256 numUsers = 1000;

        bytes memory randomness = abi.encode("benchmark_test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        address[] memory users = new address[](numUsers);
        uint256[] memory amounts = new uint256[](numUsers);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < numUsers; i++) {
            users[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))));
            amounts[i] = uint256(keccak256(abi.encode(seed, i, "amount"))) % 1000 + 1; // Random amount between 1 and 1000
            totalAmount += amounts[i];
            addPlayer(users[i], amounts[i]);
        }

        // Get winner
        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

        // Verify the winner is one of the added users
        bool isValidWinner = false;
        for (uint256 i = 0; i < numUsers; i++) {
            if (winner == users[i]) {
                isValidWinner = true;
                break;
            }
        }
        assertTrue(isValidWinner, "Winner should be one of the added users");

        // Verify total amount
        assertEq(lingoRewardsBaseRaffle.getTotalSum(randomnessCommitment), totalAmount, "Total amount should match");

        // Verify each user's amount
        for (uint256 i = 0; i < numUsers; i++) {
            assertEq(lingoRewardsBaseRaffle.getPlayerAmount(users[i]), amounts[i], "User amount should match");
        }
    }

    // Helper function to add a player with a signed message
    function addPlayer(address player, uint256 amount) internal {
        bytes32 randomnessCommitment = lingoRewardsBaseRaffle.getCurrentRaffleId();
        uint256 nonce = playerNonces[player];

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
        playerNonces[player]++;
    }
    //function to test multiple participation

    function testMultipleParticipation() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        // Add player1 multiple times with different amounts
        addPlayer(player1, 100);
        addPlayer(player1, 200);
        addPlayer(player1, 300);

        // Add player2 once
        addPlayer(player2, 400);

        // Check total amounts
        assertEq(lingoRewardsBaseRaffle.getPlayerAmount(player1), 600);
        assertEq(lingoRewardsBaseRaffle.getPlayerAmount(player2), 400);

        // Get winner and check if it's either player1 or player2
        bytes memory randomness = abi.encode("test");

        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

        assertTrue(winner == player1 || winner == player2);
    }

    function testNewRaffleWhenGameNotConcluded() public {
        bytes32 randomnessCommitment1 = keccak256(abi.encode("test1"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment1);

        bytes32 randomnessCommitment2 = keccak256(abi.encode("test2"));
        vm.prank(owner);
        vm.expectRevert(LingoRewardsBaseRaffle.GameNotConcluded.selector);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment2);
    }

    function testGetRaffleTicketsInvalidRaffleId() public {
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        bytes32 invalidRaffleId = keccak256(abi.encode("invalid"));
        bytes32 messageHash = keccak256(abi.encode(invalidRaffleId, player1, 100, 0));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);

        vm.expectRevert(LingoRewardsBaseRaffle.InvalidRaffleId.selector);
        lingoRewardsBaseRaffle.getRaffleTickets(
            invalidRaffleId,
            player1,
            100,
            0,
            LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v}),
            keccak256("randomness")
        );
    }

    function testGetRaffleTicketsCommitmentAlreadyOpened() public {
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        addPlayer(player1, 100);

        vm.prank(owner);
        lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, player2, 200, 0));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);

        vm.expectRevert(LingoRewardsBaseRaffle.CommitmentAlreadyOpened.selector);
        lingoRewardsBaseRaffle.getRaffleTickets(
            randomnessCommitment,
            player2,
            200,
            0,
            LingoRewardsBaseRaffle.Signature({r: r, s: s, v: v}),
            keccak256("randomness")
        );
    }

    function testGetWinnerWithZeroTotalSum() public {
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

        assertEq(winner, address(0));
    }

    function testBoundOrDefaultWithEqualMinMax() public {
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        lingoRewardsBaseRaffle.newRaffle(randomnessCommitment);

        addPlayer(player1, 0);

        vm.prank(owner);
        address winner = lingoRewardsBaseRaffle.getWinner(randomnessCommitment, randomness);

        assertEq(winner, address(0));
    }
}
