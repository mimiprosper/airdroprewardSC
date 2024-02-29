// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//  Imported from Chainlink contracts. It provides functionality for interacting with Chainlink's VRF.
//   Imported from OpenZeppelin, which defines the ERC20 interface.
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PrizeDistribution is VRFConsumerBase {
    // The hash used by Chainlink VRF to generate random numbers.
    // The fee in LINK (Chainlink's token) required to fulfill a VRF request.
    // Stores the last generated random number.
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    // An ERC20 token contract that will be used for prize and airdrop distributions.
    IERC20 public token;

    // Participant data
    struct Participant {
        bool registered;
        uint256 totalEntries;
        mapping(uint256 => uint256) entries; // Map entry number to randomness
    }

    // Maps addresses to Participant structs.
    mapping(address => Participant) public participants;
    // Array to store participant addresses.
    address[] public participantList;

    // Emitted when a participant is registered.
    event ParticipantRegistered(address indexed participant);
    // Emitted when a participant generates an entry.
    event EntryGenerated(
        address indexed participant,
        uint256 entryNumber,
        uint256 randomness
    );
    // Emitted when a prize is distributed.
    event PrizeDistributed(address indexed winner, uint256 amount);
    // Emitted when airdrop tokens are distributed.
    event AirdropTokensDistributed(address indexed participant, uint256 amount);

    // Constructor. Initializes the contract with the Chainlink VRF parameters and ERC20 token.
    constructor(
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash,
        uint256 _fee,
        address _token
    ) VRFConsumerBase(_vrfCoordinator, _link) {
        keyHash = _keyHash;
        fee = _fee;
        token = IERC20(_token);
    }

    // Modifier Ensures that only the token contract can call certain functions.
    modifier onlyToken() {
        require(
            msg.sender == address(token),
            "Only token contract can call this function"
        );
        _;
    }

    // Allows a participant to register by adding them to participants and participantList.
    function register() external {
        require(
            !participants[msg.sender].registered,
            "Participant already registered"
        );
        participants[msg.sender].registered = true;
        participantList.push(msg.sender);
        emit ParticipantRegistered(msg.sender);
    }

    // Participants can generate a random entry for a given entryNumber using Chainlink VRF.
    function participate(uint256 entryNumber) external {
        require(
            participants[msg.sender].registered,
            "Participant not registered"
        );
        require(entryNumber > 0, "Entry number must be greater than 0");

        // Request randomness from Chainlink VRF
        bytes32 requestId = requestRandomness(keyHash, fee);

        // Store the requestId for later verification
        participants[msg.sender].entries[entryNumber] = uint256(requestId);

        // Increase total entries for the participant
        participants[msg.sender].totalEntries++;

        emit EntryGenerated(msg.sender, entryNumber, uint256(requestId));
    }

    // Callback function called by Chainlink VRF
    function fulfillRandomness(
        bytes32 requestId,
        uint256 randomness
    ) internal override {
        // Stores the generated randomness in randomResult.
        randomResult = randomness;
    }

    // Allows a participant to claim a prize if their generated entry matches the current random result.
    function distributePrize(uint256 entryNumber, uint256 amount) external {
        require(randomResult > 0, "Random number not generated yet");
        require(
            participants[msg.sender].entries[entryNumber] == randomResult,
            "Invalid entry or randomness"
        );

        // Transfers amount of ERC20 tokens to the participant.
        token.transfer(msg.sender, amount);
        // Emit an event to notify the prize distribution
        emit PrizeDistributed(msg.sender, amount);
    }

    // Distributes airdrop tokens equally among all registered participants.
    function distributeAirdrop(uint256 totalAirdropTokens) external onlyToken {
        // Participants must have registered and have at least one entry.
        require(
            totalAirdropTokens > 0,
            "Airdrop amount must be greater than 0"
        );

        uint256 participantsCount = participantList.length;
        require(participantsCount > 0, "No participants registered");

        uint256 individualShare = totalAirdropTokens / participantsCount;
        // Transfers tokens to each participant in participantList.
        for (uint256 i = 0; i < participantsCount; i++) {
            address participantAddress = participantList[i];
            token.transfer(participantAddress, individualShare);
            emit AirdropTokensDistributed(participantAddress, individualShare);
        }
    }

    // Returns the total number of registered participants.
    function getTotalParticipants() external view returns (uint256) {
        return participantList.length;
    }

    // Returns whether a participant is registered and their total number of entries.
    function getParticipant(
        address participant
    ) external view returns (bool registered, uint256 totalEntries) {
        return (
            participants[participant].registered,
            participants[participant].totalEntries
        );
    }

    // Returns the randomness entry for a participant's given entry number.
    function getParticipantEntry(
        address participant,
        uint256 entryNumber
    ) external view returns (uint256) {
        return participants[participant].entries[entryNumber];
    }
}
