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
    mapping(address => uint256) private playerNonces;


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
        bytes32 gameId = randomnessCommitment;
        address account = player1;
        uint256 amount = 100;
        uint256 nonce = 0;

        bytes32 messageHash = keccak256(abi.encode(gameId, account, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);

        // Increase player amount
        jackpot.increasePlayerAmount(gameId, account, amount, nonce, Jackpot.Signature({r: r, s: s, v: v}), keccak256("randomness"));

        // Add assertions to check if the player amount was increased correctly
        assertEq(jackpot.getPlayerAmount(player1), 100);
    }

    function testIncreasePlayerAmountZero() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);

        // Prepare signed data with zero amount
        bytes32 gameId = randomnessCommitment;
        address account = player1;
        uint256 amount = 0;
        uint256 nonce = 0;

        bytes32 messageHash = keccak256(abi.encode(gameId, account, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);

        // Increase player amount
        jackpot.increasePlayerAmount(gameId, account, amount, nonce, Jackpot.Signature({r: r, s: s, v: v}), keccak256("randomness"));

        // Add assertions to check if the player amount was increased correctly
        assertEq(jackpot.getPlayerAmount(player1), 0);
    }

    function testIncreasePlayerAmountInvalidSignature() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);

        // Prepare data with invalid owner signature
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, player1, 100, 0));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, messageHash); // Using a different private key

        // Attempt to increase player amount with invalid signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignature.selector));
        jackpot.increasePlayerAmount(randomnessCommitment, player1, 100, 0, Jackpot.Signature({r: r, s: s, v: v}), keccak256("randomness"));
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

        // Sign the randomness opening
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, randomness));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);

        // Get winner
        vm.prank(owner);
        address winner = jackpot.getWinner(randomnessCommitment, randomness, Jackpot.Signature({r: r, s: s, v: v}));

        // Add assertions to check if a winner was selected correctly
        assertTrue(winner == player1 || winner == player2);
    }

    function testGetWinnerBoundaryValues() public {
        bytes memory randomness = abi.encode("test");
        // Setup a new game and add players
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);

        // Add multiple players
        addPlayer(player1, 100);
        addPlayer(player2, 200);

        // Sign the randomness opening
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, randomness));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);

        // Get winner with boundary values
        vm.prank(owner);
        address winner = jackpot.getWinner(randomnessCommitment, randomness, Jackpot.Signature({r: r, s: s, v: v}));

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
        bytes32 gameId = randomnessCommitment;
        address account = player1;
        uint256 amount = 100;
        uint256 nonce = 0;
        Jackpot.Signature memory invalidSignature = Jackpot.Signature({r: bytes32(0), s: bytes32(0), v: 0});

        // Attempt to increase player amount with invalid signature
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignature.selector));
        jackpot.increasePlayerAmount(gameId, account, amount, nonce, invalidSignature, keccak256("randomness"));
    }

    function testCommitmentAlreadyOpened() public {
        // Setup a new game and add players
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);
        addPlayer(player1, 100);

        // Sign the randomness opening
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, randomness));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);
        Jackpot.Signature memory signature = Jackpot.Signature({r: r, s: s, v: v});

        // Get winner for the first time
        vm.prank(owner);
        jackpot.getWinner(randomnessCommitment, randomness, signature);

        // Attempt to get winner for the second time
        vm.prank(owner);
        vm.expectRevert(Jackpot.CommitmentAlreadyOpened.selector);
        jackpot.getWinner(randomnessCommitment, randomness, signature);
    }

    function testInvalidRandomnessOpening() public {
        // Setup a new game and add players
        bytes memory randomness = abi.encode("test");
        bytes32 randomnessCommitment = keccak256(randomness);
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);
        addPlayer(player1, 100);

        bytes memory invalidRandomness = abi.encode("invalid");
        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, invalidRandomness));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);
        Jackpot.Signature memory signature = Jackpot.Signature({r: r, s: s, v: v});

        vm.expectRevert(Jackpot.InvalidRandomnessOpening.selector);
        jackpot.getWinner(randomnessCommitment, invalidRandomness, signature);
    }

    function testReplayAttackSameGame() public {
        // Setup a new game
        bytes32 randomnessCommitment = keccak256(abi.encode("test"));
        vm.prank(owner);
        jackpot.newGame(randomnessCommitment);

        // Prepare signed data
        bytes32 gameId = randomnessCommitment;
        address account = player1;
        uint256 amount = 100;
        uint256 nonce = 0;

        bytes32 messageHash = keccak256(abi.encode(gameId, account, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);
        Jackpot.Signature memory signature = Jackpot.Signature({r: r, s: s, v: v});

        // Increase player amount
        jackpot.increasePlayerAmount(gameId, account, amount, nonce, signature, keccak256("randomness"));

        // Try to replay the same transaction in the same game
        vm.expectRevert(Jackpot.InvalidNonce.selector);
        jackpot.increasePlayerAmount(gameId, account, amount, nonce, signature, keccak256("randomness"));
    }


    // Helper function to add a player with a signed message
    function addPlayer(address player, uint256 amount) internal {
        bytes32 randomnessCommitment = jackpot.getCurrentGameId();
        uint256 nonce = playerNonces[player];

        bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, player, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);

        jackpot.increasePlayerAmount(randomnessCommitment, player, amount, nonce, Jackpot.Signature({r: r, s: s, v: v}), keccak256("randomness"));

        playerNonces[player]++;    
    }

    //function to test multiple participation
    function testMultipleParticipation() public {
    // Setup a new game
    bytes32 randomnessCommitment = keccak256(abi.encode("test"));
    vm.prank(owner);
    jackpot.newGame(randomnessCommitment);

    // Add player1 multiple times with different amounts
    addPlayer(player1, 100);
    addPlayer(player1, 200);
    addPlayer(player1, 300);

    // Add player2 once
    addPlayer(player2, 400);

    // Check total amounts
    assertEq(jackpot.getPlayerAmount(player1), 600);
    assertEq(jackpot.getPlayerAmount(player2), 400);

    // Get winner and check if it's either player1 or player2
    bytes memory randomness = abi.encode("test");
    bytes32 messageHash = keccak256(abi.encode(randomnessCommitment, randomness));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, messageHash);
    
    vm.prank(owner);
    address winner = jackpot.getWinner(randomnessCommitment, randomness, Jackpot.Signature({r: r, s: s, v: v}));

        assertTrue(winner == player1 || winner == player2);
    }
}
