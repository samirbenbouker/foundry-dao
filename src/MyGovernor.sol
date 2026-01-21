// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title MyGovernor
 * @author Samir Ben Bouker
 * @notice A DAO governance contract based on OpenZeppelin Governor + Timelock
 * @dev This contract allows token holders (IVotes) to:
 *      - Create proposals
 *      - Vote on proposals (For/Against/Abstain)
 *      - Enforce quorum
 *      - Queue successful proposals in a Timelock
 *      - Execute them after the timelock delay
 *
 * Typical architecture:
 *   GovToken (ERC20Votes) -> MyGovernor -> TimelockController -> Target contracts (e.g. Box)
 */
contract MyGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /**
     * @notice Creates the Governor
     * @param _token The voting token (must implement IVotes, e.g. ERC20Votes)
     * @param _timelock The timelock that will queue and execute approved proposals
     *
     * Inherited constructors configure the DAO:
     * - Governor("MyGovernor"): name used in UI / offchain systems
     * - GovernorSettings(votingDelay, votingPeriod, proposalThreshold)
     * - GovernorVotes(_token): tells Governor where voting power comes from
     * - GovernorVotesQuorumFraction(4): quorum is 4% of total supply (snapshot based)
     * - GovernorTimelockControl(_timelock): execution must go through timelock
     */
    constructor(IVotes _token, TimelockController _timelock)
        Governor("MyGovernor")
        GovernorSettings(
            1, // votingDelay: how many BLOCKS after proposing voting becomes active
            // In tests you often set this to 1 block for speed.
            // On mainnet it might be ~7200 blocks (~1 day on Ethereum).
            50400, // votingPeriod: how many BLOCKS voting lasts
            // On Ethereum, ~50400 blocks is roughly ~1 week (assuming ~12s blocks).
            0 // proposalThreshold: minimum votes required to create a proposal
            // 0 means anyone can propose (can be spammy in production).
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
    {}

    // -------------------------------------------------------------------------
    // Required overrides (multiple inheritance glue)
    // -------------------------------------------------------------------------
    // Because we inherit from multiple extensions, some functions exist in more
    // than one parent contract. Solidity requires us to explicitly override and
    // choose the final implementation.
    //
    // In all of these cases, we simply delegate to `super` so that OpenZeppelin’s
    // combined logic is applied correctly (especially for timelock integration).
    // -------------------------------------------------------------------------

    /**
     * @notice Returns the current proposal state (Pending, Active, Succeeded, Queued, Executed, etc.)
     * @dev Both Governor and GovernorTimelockControl define state(), so we must override.
     *      The timelock extension adds extra states like Queued and changes how transitions work.
     */
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    /**
     * @notice Whether a proposal needs to be queued in the timelock before execution
     * @dev With a timelock-enabled governor, successful proposals typically require queuing.
     */
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /**
     * @notice Minimum votes required to create a proposal
     * @dev Provided by GovernorSettings; override required due to multiple inheritance.
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    /**
     * @dev Queues proposal actions into the timelock.
     * Called when you do governor.queue(...)
     * Returns the ETA (timestamp) at which the proposal can be executed.
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev Executes the queued proposal actions via the timelock.
     * Called when you do governor.execute(...)
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev Cancels a proposal.
     * With timelock, cancellation may involve canceling a queued operation too.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev Returns the address that is allowed to execute proposal actions.
     * With GovernorTimelockControl, this is typically the timelock itself.
     */
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
