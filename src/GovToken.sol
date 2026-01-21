// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title GovToken
 * @author Samir Ben Bouker
 * @notice ERC20 governance token with voting power and delegation
 * @dev Designed to work with OpenZeppelin Governor
 *
 * Key features:
 * - ERC20 transferable token
 * - Vote delegation (ERC20Votes)
 * - Snapshot-based voting power
 * - Gasless approvals via EIP-2612 (permit)
 */
contract GovToken is ERC20, ERC20Permit, ERC20Votes {
    /**
     * @notice Deploys the governance token
     * @dev Token name and symbol are passed to ERC20
     *      Permit uses the same name for EIP-712 domain separator
     */
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {}

    /**
     * @notice Mints new governance tokens
     * @dev ⚠️ For testing only
     *      In production this should be restricted
     *      (e.g. onlyOwner, DAO-controlled, or removed entirely)
     * @param _to Address receiving the tokens
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    /**
     * @dev Hook that is called on every token transfer, mint, or burn
     *
     * Required override because:
     * - ERC20 updates balances
     * - ERC20Votes updates voting power snapshots
     *
     * This ensures voting power always matches token balances
     * at the correct block for governance proposals
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /**
     * @notice Returns the current nonce for an address
     * @dev Required override due to multiple inheritance
     *      Used by ERC20Permit to prevent signature replay attacks
     * @param owner Address to query nonce for
     * @return Current nonce value
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
