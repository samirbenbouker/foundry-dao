// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Box
 * @author Samir Ben Bouker
 * @notice Simple storage contract controlled by an owner
 * @dev In a governance setup, ownership is usually transferred
 *      to a TimelockController so changes must go through DAO votes
 */
contract Box is Ownable {
    // Private state variable to store a single number
    uint256 private s_number;

    // Event emitted whenever the stored number changes
    // Useful for off-chain indexing, UI updates, and debugging
    event NumberChanged(uint256 number);

    /**
     * @notice Sets the initial owner of the contract
     * @dev `msg.sender` will be the deployer
     *      In governance systems, ownership is later transferred
     *      to a TimelockController
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @notice Stores a new number
     * @dev Restricted to the owner only
     *      When owned by a Timelock, this function can ONLY be
     *      called via a successful governance proposal
     * @param _number The new number to store
     */
    function store(uint256 _number) public onlyOwner {
        // Update storage
        s_number = _number;

        // Emit event for transparency and tracking
        emit NumberChanged(_number);
    }

    /**
     * @notice Returns the currently stored number
     * @dev Public read-only function, does not modify state
     * @return The stored uint256 value
     */
    function getNumber() external view returns (uint256) {
        return s_number;
    }
}
