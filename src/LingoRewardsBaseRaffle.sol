// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {console} from "forge-std/console.sol";

import {IntervalTree} from "./libraries/IntervalTree.sol";

/// @title LingoRewardsBaseRaffle
/// @notice A contract for managing raffles with randomness and interval tree-based ticket allocation
/// @dev Inherits from Context, Ownable, and Pausable
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

    /// @notice Address of the signer for validating signatures
    address private signer;
    /// @notice ID of the current active raffle
    bytes32 private currentRaffleId;
    /// @notice Mapping of raffle IDs to Raffle structs
    mapping(bytes32 => Raffle) private raffles;
    /// @notice Mapping to check if a raffle exists
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

    /// @notice Constructor to initialize the contract
    /// @param initialOwner Address of the initial contract owner
    /// @param initialSigner Address of the initial signer for signature validation
    constructor(address initialOwner, address initialSigner) Ownable(initialOwner) {
        signer = initialSigner;
        raffles[currentRaffleId].commitmentOpened = true;
    }

    /// @notice Sets a new signer address
    /// @param _signer The new signer address
    function setSigner(address _signer) external {
        signer = _signer;
    }

    /// @notice Pauses the contract
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @notice Retrieves the current raffle ID
    /// @return The current raffle ID
    function getCurrentRaffleId() external view returns (bytes32) {
        return currentRaffleId;
    }

    /// @notice Retrieves the randomness commitment for a given raffle ID
    /// @param key The raffle ID
    /// @return The randomness commitment
    function getRaffleRandomnessCommitment(bytes32 key) external view returns (bytes32) {
        return raffles[key].randomnessCommitment;
    }

    /// @notice Retrieves the current randomness for a given raffle ID
    /// @param key The raffle ID
    /// @return The current randomness
    function getRaffleCurrentRandomness(bytes32 key) external view returns (bytes32) {
        return raffles[key].currentRandomness;
    }

    /// @notice Checks if the commitment for a given raffle ID is opened
    /// @param key The raffle ID
    /// @return True if the commitment is opened, false otherwise
    function getRaffleCommitmentOpened(bytes32 key) external view returns (bool) {
        return raffles[key].commitmentOpened;
    }

    /// @notice Checks if a raffle exists for a given raffle ID
    /// @param key The raffle ID
    /// @return True if the raffle exists, false otherwise
    function getRaffleExists(bytes32 key) external view returns (bool) {
        return raffleExists[key];
    }

    /// @notice Retrieves the total sum of tickets for a given raffle ID
    /// @param key The raffle ID
    /// @return The total sum of tickets
    function getTotalSum(bytes32 key) external view returns (uint256) {
        return raffles[key].tree.totalSum;
    }

    /// @notice Creates a new raffle
    /// @param randomnessCommitment The commitment for the raffle's randomness
    function newRaffle(bytes32 randomnessCommitment) external whenNotPaused onlyOwner {
        if (!raffles[currentRaffleId].commitmentOpened) revert GameNotConcluded();
        currentRaffleId = randomnessCommitment;
        if (raffleExists[currentRaffleId]) revert RaffleAlreadyExists();
        raffleExists[currentRaffleId] = true;
        raffles[currentRaffleId].tree.initialize();
        raffles[currentRaffleId].randomnessCommitment = randomnessCommitment;
        raffles[currentRaffleId].currentRandomness = randomnessCommitment;
        emit RaffleCreated(currentRaffleId, randomnessCommitment);
    }

    /// @notice Emits an event with the provided data
    /// @param data The data to be included in the event
    function crackTheEgg(bytes32 data) external onlyOwner {
        emit CrackTheEgg(data);
    }

    /// @notice Allows a player to get raffle tickets
    /// @param raffleId The ID of the raffle
    /// @param account The address of the player
    /// @param amount The amount of tickets to add
    /// @param nonce The nonce for the player's transaction
    /// @param signature The signature for verification
    /// @param randomness Additional randomness to update the raffle's current randomness
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

    /// @notice Retrieves the amount of tickets for a player in the current raffle
    /// @param account The address of the player
    /// @return The amount of tickets for the player
    function getPlayerAmount(address account) external view returns (uint256) {
        Raffle storage raffle = raffles[currentRaffleId];
        return raffle.tree.get(account);
    }

    /// @notice Determines the winner of a raffle
    /// @param raffleId The ID of the raffle
    /// @param randomnessOpening The opening of the randomness commitment
    /// @return The address of the winner
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

    /// @notice Bounds a value within a given range or returns a default
    /// @param value The value to bound
    /// @param min The minimum of the range
    /// @param max The maximum of the range
    /// @return The bounded value or 0 if the range is invalid
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

    /// @notice Verifies the signature for a given hash
    /// @param hash The hash to verify
    /// @param signature The signature to check
    function checkSignature(bytes32 hash, Signature memory signature) private view {
        if (ECDSA.recover(hash, signature.v, signature.r, signature.s) != signer) {
            revert ECDSA.ECDSAInvalidSignature();
        }
    }
}
