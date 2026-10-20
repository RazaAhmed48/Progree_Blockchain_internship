// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * TASK 4 - Multi-Party Escrow / Crowdfunding Contract
 * - Many contributors fund a campaign
 * - Funds are locked until the deadline
 * - Goal met  -> creator withdraws
 * - Goal missed -> every contributor can claim an automatic refund
 * - Protected against reentrancy (checks-effects-interactions + nonReentrant lock)
 */
contract MultiPartyEscrow {
    struct Campaign {
        address creator;
        string title;
        uint256 goal;         // in wei
        uint256 deadline;     // unix timestamp
        uint256 totalRaised;  // in wei
        bool withdrawn;
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    // campaignId => contributor => amount
    mapping(uint256 => mapping(address => uint256)) public contributions;

    // --- Reentrancy guard ---
    bool private locked;
    modifier nonReentrant() {
        require(!locked, "Reentrant call blocked");
        locked = true;
        _;
        locked = false;
    }

    event CampaignCreated(uint256 indexed id, address indexed creator, uint256 goal, uint256 deadline);
    event Contributed(uint256 indexed id, address indexed contributor, uint256 amount);
    event Withdrawn(uint256 indexed id, address indexed creator, uint256 amount);
    event Refunded(uint256 indexed id, address indexed contributor, uint256 amount);

    function createCampaign(string memory title, uint256 goal, uint256 durationMinutes)
        external
        returns (uint256 id)
    {
        require(goal > 0, "Goal must be > 0");
        require(durationMinutes > 0, "Duration must be > 0");

        id = campaignCount++;
        campaigns[id] = Campaign({
            creator: msg.sender,
            title: title,
            goal: goal,
            deadline: block.timestamp + (durationMinutes * 1 minutes),
            totalRaised: 0,
            withdrawn: false
        });
        emit CampaignCreated(id, msg.sender, goal, campaigns[id].deadline);
    }

    // --- Transaction conditional checks ---
    function contribute(uint256 id) external payable {
        Campaign storage c = campaigns[id];
        require(c.creator != address(0), "Campaign does not exist");
        require(block.timestamp < c.deadline, "Campaign ended");
        require(msg.value > 0, "Send some ETH");

        contributions[id][msg.sender] += msg.value;
        c.totalRaised += msg.value;
        emit Contributed(id, msg.sender, msg.value);
    }

    // Creator withdraws only if the goal is reached and the deadline has passed
    function withdrawFunds(uint256 id) external nonReentrant {
        Campaign storage c = campaigns[id];
        require(msg.sender == c.creator, "Only creator");
        require(block.timestamp >= c.deadline, "Campaign still running");
        require(c.totalRaised >= c.goal, "Goal not reached");
        require(!c.withdrawn, "Already withdrawn");

        c.withdrawn = true;                 // EFFECT first
        uint256 amount = c.totalRaised;

        (bool ok, ) = payable(c.creator).call{value: amount}("");  // INTERACTION last
        require(ok, "Transfer failed");
        emit Withdrawn(id, c.creator, amount);
    }

    // --- Automated refund pathway if the deadline fails ---
    function refund(uint256 id) external nonReentrant {
        Campaign storage c = campaigns[id];
        require(block.timestamp >= c.deadline, "Campaign still running");
        require(c.totalRaised < c.goal, "Goal was reached, no refund");

        uint256 amount = contributions[id][msg.sender];
        require(amount > 0, "Nothing to refund");

        contributions[id][msg.sender] = 0;  // EFFECT first (prevents reentrancy)
        c.totalRaised -= amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");  // INTERACTION last
        require(ok, "Refund failed");
        emit Refunded(id, msg.sender, amount);
    }
}
