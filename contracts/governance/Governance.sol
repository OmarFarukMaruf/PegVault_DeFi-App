// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error VotingClosed();
error AlreadyExecuted();

contract Governance {
    struct Proposal {
        address target;
        bytes data;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
    }

    IERC20 public immutable govToken;
    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public voted;

    uint256 public constant VOTING_PERIOD = 3 days;

    constructor(address _govToken) {
        govToken = IERC20(_govToken);
    }

    function propose(
        address target,
        bytes calldata data
    ) external returns (uint256) {
        proposalCount++;

        proposals[proposalCount] = Proposal({
            target: target,
            data: data,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + VOTING_PERIOD,
            executed: false
        });

        return proposalCount;
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];

        if (block.timestamp > p.deadline) revert VotingClosed();
        require(!voted[proposalId][msg.sender], "Already voted");

        uint256 weight = govToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        voted[proposalId][msg.sender] = true;

        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }
    }

    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];

        require(block.timestamp > p.deadline, "Still voting");
        if (p.executed) revert AlreadyExecuted();
        require(p.votesFor > p.votesAgainst, "Proposal failed");

        p.executed = true;

        (bool success, ) = p.target.call(p.data);
        require(success, "Execution failed");
    }
}
