// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CommitRevealVoting {
    
    // --- Actors & State Variables ---
    address public administrator;
    
    enum Phase { Commit, Reveal, Ended }
    Phase public currentPhase;
    
    // Tally of votes per option
    mapping(string => uint256) public voteCounts;

    // To check if an option is actually on the ballot
    mapping(string => bool) public validOptions;

    // A list to keep track of the options for the frontend to read
    string[] public optionsList;
    
    // Tracking voters
    mapping(address => bytes32) public commits;
    mapping(address => bool) public hasCommitted;
    mapping(address => bool) public hasRevealed;

    // --- Events ---
    event VoteCommitted(address indexed voter);
    event VoteRevealed(address indexed voter, string vote);
    event PhaseChanged(Phase newPhase);

    // --- Modifiers ---
    modifier onlyAdmin() {
        require(msg.sender == administrator, "Only administrator can call this");
        _;
    }

    modifier atPhase(Phase _phase) {
        require(currentPhase == _phase, "Function cannot be called at this phase");
        _;
    }

    // --- Constructor ---
    constructor() {
        administrator = msg.sender;
        currentPhase = Phase.Commit; // Voting starts in the Commit phase
    }

    // --- Admin Functions ---
    // The admin moves the contract from Commit -> Reveal -> Ended
    function advancePhase() public onlyAdmin {
        if (currentPhase == Phase.Commit) {
            currentPhase = Phase.Reveal;
        } else if (currentPhase == Phase.Reveal) {
            currentPhase = Phase.Ended;
        } else {
            revert("Voting already ended");
        }
        emit PhaseChanged(currentPhase);
    }

    function addOption(string memory _option) public onlyAdmin atPhase(Phase.Commit) {
        require(!validOptions[_option], "Option already exists");
        validOptions[_option] = true;
        optionsList.push(_option);
    }
    
    // --- Voter Functions ---

    /**
     * @dev Step 1: Commit Phase. Voter submits their obfuscated vote.
     * @param _commitmentHash The keccak256 hash of (vote + salt + voter_address)
     */
    function commitVote(bytes32 _commitmentHash) public atPhase(Phase.Commit) {
        // require(msg.sender != administrator, "The administrator is not allowed to vote");
        require(!hasCommitted[msg.sender], "You have already committed a vote");
        
        commits[msg.sender] = _commitmentHash;
        hasCommitted[msg.sender] = true;
        
        emit VoteCommitted(msg.sender);
    }

    /**
     * @dev Step 2: Reveal Phase. Voter reveals their plaintext vote and salt.
     * @param _vote The plaintext vote (e.g., "Yes" or "No")
     * @param _salt The secret random string used during the commit
     */
    function revealVote(string memory _vote, string memory _salt) public atPhase(Phase.Reveal) {
        require(hasCommitted[msg.sender], "You did not commit a vote");
        require(!hasRevealed[msg.sender], "You have already revealed your vote");
        require(validOptions[_vote], "Invalid vote option. Candidate not on ballot.");
        // Recompute the hash using the exact same logic: hash(vote + salt + voter_address)
        bytes32 computedHash = keccak256(abi.encodePacked(_vote, _salt, msg.sender));

        // Check for "Mismatch hashmap" failure case
        require(computedHash == commits[msg.sender], "Hash mismatch! Invalid vote or salt");

        // Mark as revealed so they can't vote twice
        hasRevealed[msg.sender] = true;

        // Inside revealVote(), replace the if/else with this:

        // 1. Check if the vote they revealed is actually on the ballot
        require(validOptions[_vote], "Invalid vote option. Candidate not on ballot.");

        // 2. Increment the vote count for that specific option
        voteCounts[_vote]++;

        emit VoteRevealed(msg.sender, _vote);
    }

    // --- Helper Function for the Demo ---
    
    /**
     * @dev Helper function to let users easily compute their hash in Remix before committing.
     * In a real app, this would be done in javascript on the frontend so the plaintext
     * never touches the blockchain RPC until the reveal phase.
     */
    function generateHash(string memory _vote, string memory _salt) public view returns (bytes32) {
        return keccak256(abi.encodePacked(_vote, _salt, msg.sender));
    }
    /**
     * @dev Helper function to return the current phase as a readable string
     * instead of an integer (0, 1, or 2).
     */
    function getPhaseName() public view returns (string memory) {
        if (currentPhase == Phase.Commit) {
            return "Voting";
        } else if (currentPhase == Phase.Reveal) {
            return "Reveal";
        } else if (currentPhase == Phase.Ended) {
            return "Ended";
        } else {
            return "Unknown";
        }
    }
}




