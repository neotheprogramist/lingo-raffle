// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {console} from "forge-std/console.sol";

import {IntervalTree} from "./libraries/IntervalTree.sol";

contract Jackpot is Context, Ownable {
    using IntervalTree for IntervalTree.Tree;

    struct Game {
        IntervalTree.Tree tree;
        bytes32 randomnessCommitment;
        bytes32 currentRandomness;
        bool commitmentOpened;
        mapping(address => uint256) playerNonces;
    }

    struct IncreasePlayerAmountData {
        bytes32 gameId;
        address account;
        uint256 amount;
        uint256 nonce;
        Signature signature;
    }

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    bytes32 private currentGameId;
    mapping(bytes32 => Game) private games;
    mapping(bytes32 => bool) private gameExists;

    error GameAlreadyExists();
    error InvalidSignature();
    error CommitmentAlreadyOpened();
    error InvalidRandomnessOpening();
    error InvalidNonce();
    error InvalidGameId();

    modifier onlySignedByOwner(IncreasePlayerAmountData calldata data) {
        bytes32 hash = keccak256(abi.encode(data.gameId, data.account, data.amount, data.nonce));
        if (ECDSA.recover(hash, data.signature.v, data.signature.r, data.signature.s) != owner()) {
            revert ECDSA.ECDSAInvalidSignature();
        }
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    function getCurrentGameId() external view returns (bytes32) {
        return currentGameId;
    }

    function getGameRandomnessCommitment(bytes32 key) external view returns (bytes32) {
        return games[key].randomnessCommitment;
    }

    function getGameCurrentRandomness(bytes32 key) external view returns (bytes32) {
        return games[key].currentRandomness;
    }

    function getGameCommitmentOpened(bytes32 key) external view returns (bool) {
        return games[key].commitmentOpened;
    }

    function getGameExists(bytes32 key) external view returns (bool) {
        return gameExists[key];
    }

    function newGame(bytes32 randomnessCommitment) external onlyOwner {
        currentGameId = randomnessCommitment;
        if (gameExists[currentGameId]) revert GameAlreadyExists();
        gameExists[currentGameId] = true;
        games[currentGameId].tree.initialize();
        games[currentGameId].randomnessCommitment = randomnessCommitment;
        games[currentGameId].currentRandomness = randomnessCommitment;
    }

    function increasePlayerAmount(IncreasePlayerAmountData calldata data, bytes32 randomness)
        external
        onlySignedByOwner(data)
    {
        if (data.gameId != currentGameId) revert InvalidGameId();
        Game storage game = games[currentGameId];
        if (game.commitmentOpened) revert CommitmentAlreadyOpened();
        if (data.nonce != game.playerNonces[data.account]) revert InvalidNonce();
        game.playerNonces[data.account]++;
        game.tree.insert(data.account, data.amount);
        game.currentRandomness = keccak256(abi.encode(game.currentRandomness, randomness));
    }

    function getPlayerAmount(address account) external view returns (uint256) {
        Game storage game = games[currentGameId];
        return game.tree.get(account);
    }

    function getWinner(bytes calldata randomnessOpening) external returns (address) {
        Game storage game = games[currentGameId];
        if (keccak256(randomnessOpening) != game.randomnessCommitment) {
            revert InvalidRandomnessOpening();
        }
        if (game.commitmentOpened) revert CommitmentAlreadyOpened();
        game.commitmentOpened = true;
        uint256 currentRandomness = uint256(keccak256(abi.encode(game.currentRandomness, randomnessOpening)));
        uint256 max = game.tree.totalSum;
        uint256 boundedRandomness = bound(currentRandomness, 0, max);
        return game.tree.getByPointOnInterval(boundedRandomness);
    }

    function bound(uint256 value, uint256 min, uint256 max) private pure returns (uint256) {
        uint256 range = max - min;
        while (range * (value / range) >= value) {
            value = uint256(keccak256(abi.encode(value)));
        }
        return min + (value % range);
    }
}
