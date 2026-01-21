// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title TimeLock
 * @author Samir Ben Bouker
 * @notice Timelock contract used by the DAO to delay execution of proposals
 * @dev This contract acts as the "owner" or "executor" of governance-controlled
 *      contracts (e.g. Box).
 *
 * Architecture:
 *   MyGovernor -> TimeLock -> Target contracts
 *
 * The timelock:
 * - Receives queued operations from the Governor
 * - Enforces a mandatory delay (`minDelay`)
 * - Executes transactions only after the delay expires
 */
contract TimeLock is TimelockController {
    /**
     * @notice Deploys the timelock contract
     * @param _minDelay Minimum delay (in seconds) before an operation can be executed
     * @param _proposers Addresses allowed to propose (queue) operations
     *        In a DAO, this is usually the Governor contract
     * @param _executors Addresses allowed to execute queued operations
     *        Often set to `address(0)` to allow anyone to execute
     *
     * @dev The last argument (`msg.sender`) becomes the initial admin.
     *      Best practice:
     *        1. Deploy timelock
     *        2. Grant PROPOSER_ROLE to Governor
     *        3. Optionally grant EXECUTOR_ROLE to address(0)
     *        4. Revoke DEFAULT_ADMIN_ROLE from deployer
     */
    constructor(uint256 _minDelay, address[] memory _proposers, address[] memory _executors)
        TimelockController(
            _minDelay,
            _proposers,
            _executors,
            msg.sender // initial admin (should be renounced after setup)
        )
    {}
}
