// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    // minDelay is how long you have to wait before executing
    // proposers is the list of addresses that can propose
    // executors is the list of addresses that can execute
    constructor(uint256 _minDelay, address[] memory _proposers, address[] memory _executors)
        TimelockController(_minDelay, _proposers, _executors, msg.sender)
    {}
}
