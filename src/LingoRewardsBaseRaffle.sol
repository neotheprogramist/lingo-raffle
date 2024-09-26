// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {console} from "forge-std/console.sol";

import {IntervalTree} from "./libraries/IntervalTree.sol";

contract LingoRewardsBaseRaffle is Context, Ownable, Pausable {
    using IntervalTree for IntervalTree.Tree;

    struct Raffle {
        IntervalTree.Tree tree;
        bytes32 randomnessCommitment;
        bytes32 currentRandomness;
        bool commitmentOpened;
        mapping(address => uint256) playerNonces;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    address private signer;
    bytes32 private currentRaffleId;
    mapping(bytes32 => Raffle) private raffles;
    mapping(bytes32 => bool) private raffleExists;

    event RaffleCreated(bytes32 indexed raffleId, bytes32 randomnessCommitment);
    event PlayerAmountIncreased(bytes32 indexed raffleId, address indexed player, uint256 amount, uint256 nonce);
    event WinnerDeclared(bytes32 indexed raffleId, address winner);
    event CrackTheEgg(bytes32 data);

    error RaffleAlreadyExists();
    error InvalidSignature();
    error CommitmentAlreadyOpened();
    error InvalidRandomnessOpening();
    error InvalidNonce();
    error InvalidRaffleId();
    error GameNotConcluded();

    constructor(address initialOwner, address initialSigner) Ownable(initialOwner) {
        signer = initialSigner;
        raffles[currentRaffleId].commitmentOpened = true;
    }

    function setSigner(address _signer) external {
        signer = _signer;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getCurrentRaffleId() external view returns (bytes32) {
        return currentRaffleId;
    }

    function getRaffleRandomnessCommitment(bytes32 key) external view returns (bytes32) {
        return raffles[key].randomnessCommitment;
    }

    function getRaffleCurrentRandomness(bytes32 key) external view returns (bytes32) {
        return raffles[key].currentRandomness;
    }

    function getRaffleCommitmentOpened(bytes32 key) external view returns (bool) {
        return raffles[key].commitmentOpened;
    }

    function getRaffleExists(bytes32 key) external view returns (bool) {
        return raffleExists[key];
    }

    function getTotalSum(bytes32 key) external view returns (uint256) {
        return raffles[key].tree.totalSum;
    }

    function newRaffle(bytes32 randomnessCommitment) external whenNotPaused onlyOwner {
        if (!raffles[currentRaffleId].commitmentOpened) revert GameNotConcluded();
        currentRaffleId = randomnessCommitment;
        if (raffleExists[currentRaffleId]) revert RaffleAlreadyExists();
        // raffles[currentRaffleId].commitmentOpened = false;
        raffleExists[currentRaffleId] = true;
        raffles[currentRaffleId].tree.initialize();
        raffles[currentRaffleId].randomnessCommitment = randomnessCommitment;
        raffles[currentRaffleId].currentRandomness = randomnessCommitment;
        emit RaffleCreated(currentRaffleId, randomnessCommitment);
    }

    function crackTheEgg(bytes32 data) external onlyOwner {
        emit CrackTheEgg(data);
    }

    function getRaffleTickets(
        bytes32 raffleId,
        address account,
        uint256 amount,
        uint256 nonce,
        Signature calldata signature,
        bytes32 randomness
    ) external whenNotPaused {
        bytes32 hash = keccak256(abi.encode(raffleId, account, amount, nonce));
        checkSignature(hash, signature);
        if (raffleId != currentRaffleId) revert InvalidRaffleId();
        Raffle storage raffle = raffles[currentRaffleId];
        if (raffle.commitmentOpened) revert CommitmentAlreadyOpened();
        if (nonce != raffle.playerNonces[account]) revert InvalidNonce();
        raffle.playerNonces[account]++;
        raffle.tree.insert(account, amount);
        raffle.currentRandomness = keccak256(abi.encode(raffle.currentRandomness, randomness));
        emit PlayerAmountIncreased(raffleId, account, amount, nonce);
    }

    function getPlayerAmount(address account) external view returns (uint256) {
        Raffle storage raffle = raffles[currentRaffleId];
        return raffle.tree.get(account);
    }

    function getWinner(bytes32 raffleId, bytes calldata randomnessOpening)
        external
        whenNotPaused
        onlyOwner
        returns (address)
    {
        Raffle storage raffle = raffles[currentRaffleId];
        if (keccak256(randomnessOpening) != raffle.randomnessCommitment) {
            revert InvalidRandomnessOpening();
        }
        if (raffle.commitmentOpened) revert CommitmentAlreadyOpened();
        raffle.commitmentOpened = true;
        uint256 currentRandomness = uint256(keccak256(abi.encode(raffle.currentRandomness, randomnessOpening)));
        uint256 max = raffle.tree.totalSum;
        uint256 boundedRandomness = boundOrDefault(currentRandomness, 0, max);
        address winner = raffle.tree.getByPointOnInterval(boundedRandomness);
        emit WinnerDeclared(raffleId, winner);
        return winner;
    }

    function boundOrDefault(uint256 value, uint256 min, uint256 max) private pure returns (uint256) {
        if (max > min) {
            uint256 range = max - min;
            while (range * (type(uint256).max / range) <= value) {
                value = uint256(keccak256(abi.encode(value)));
            }
            return min + (value % range);
        } else {
            return 0;
        }
    }

    function checkSignature(bytes32 hash, Signature memory signature) private view {
        if (ECDSA.recover(hash, signature.v, signature.r, signature.s) != signer) {
            revert ECDSA.ECDSAInvalidSignature();
        }
    }
}
