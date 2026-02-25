// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract Timelock {
    uint256 public constant DELAY = 2 days;

    mapping(bytes32 => uint256) public queued;

    function queue(
        address target,
        bytes calldata data
    ) external returns (bytes32) {
        bytes32 txId = keccak256(abi.encode(target, data));

        queued[txId] = block.timestamp + DELAY;

        return txId;
    }

    function execute(address target, bytes calldata data) external {
        bytes32 txId = keccak256(abi.encode(target, data));

        require(block.timestamp >= queued[txId], "Delay not passed");

        delete queued[txId];

        (bool success, ) = target.call(data);
        require(success, "Execution failed");
    }
}
