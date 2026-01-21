// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "src/MyGovernor.sol";
import {Box} from "src/Box.sol";
import {TimeLock} from "src/TimeLock.sol";
import {GovToken} from "src/GovToken.sol";

/**
 * @title MyGovernorTest
 * @notice End-to-end test for a Governor + Timelock governance flow
 * @dev This test covers:
 *      - Setup: token, delegation, timelock, governor, roles, ownership transfer
 *      - Negative test: direct calls to Box fail
 *      - Positive test: propose -> vote -> queue -> execute succeeds
 */
contract MyGovernorTest is Test {
    // Core governance system
    MyGovernor governor;
    Box box;
    TimeLock timelock;
    GovToken govToken;

    // A test user who will hold tokens and vote
    address public USER = makeAddr("user");

    // Initial token supply minted to USER
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    // Timelock constructor expects arrays of proposer/executor addresses
    // (we pass empty arrays and configure roles later)
    address[] proposers;
    address[] executors;

    // These arrays describe the proposal's actions:
    // targets[i] will be called with calldatas[i] and values[i]
    bytes[] calldatas;
    address[] targets;
    uint256[] values;

    // Timelock delay is in SECONDS (timestamp-based)
    uint256 public constant MIN_DELAY = 3600; // 1 hour

    // Governor delay/period are in BLOCKS (blocknumber-based by default)
    uint256 public constant VOTING_DELAY = 1; // 1 block before voting starts
    uint256 public constant VOTING_PERIOD = 50400; // voting duration in blocks

    /**
     * @notice Deploys and configures the full governance system
     */
    function setUp() public {
        // 1) Deploy governance token and mint to USER
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        // 2) Delegate voting power to USER
        // IMPORTANT: With ERC20Votes, holding tokens is not enough.
        // Votes only count once delegated (even self-delegation).
        vm.prank(USER);
        govToken.delegate(USER);

        // 3) Deploy timelock and governor
        // We pass empty proposer/executor arrays and grant roles manually below.
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        // 4) Configure timelock roles
        // - PROPOSER_ROLE: who can schedule operations (should be the Governor)
        // - EXECUTOR_ROLE: who can execute scheduled operations (often anyone)
        // - DEFAULT_ADMIN_ROLE: super-admin (should be renounced)
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        // Give the Governor permission to queue proposals in the timelock
        timelock.grantRole(proposerRole, address(governor));

        // Allow anyone to execute queued operations
        // (permissionless execution is common DAO practice)
        timelock.grantRole(executorRole, address(0));

        // Remove admin power to avoid centralized control
        // NOTE: in many setups you'd revoke from the deployer EOA,
        // here it’s the test contract address.
        timelock.revokeRole(adminRole, address(this));

        // 5) Deploy the Box and transfer ownership to the timelock
        // This ensures ONLY governance (via timelock) can call store().
        box = new Box();
        box.transferOwnership(address(timelock));
    }

    /**
     * @notice Sanity check: you can't call Box.store() directly anymore
     * @dev Because Box owner is the timelock, and this test contract is not the timelock.
     */
    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert(); // expect onlyOwner failure
        box.store(1);
    }

    /**
     * @notice Full governance flow:
     *         propose -> becomes active -> vote -> succeeded -> queue -> queued -> execute -> executed
     */
    function testGovernanceUpdateBox() public {
        // The new value we want governance to set inside Box
        uint256 valueToStore = 888;

        // Human-readable description of the proposal
        string memory description = "store 1 in Box";

        // Encode the function call we want Box to execute:
        // store(uint256) with valueToStore
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        // Build the proposal actions arrays (single action in this case):
        // Call Box.store(valueToStore) with 0 ETH
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // ---------------------------------------------------------------------
        // 1) PROPOSE
        // ---------------------------------------------------------------------
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Immediately after proposing, state is usually Pending (0)
        console.log("Proposal State: ", uint256(governor.state(proposalId))); // Pending = 0

        // Governor's voting delay is in BLOCKS by default.
        // vm.roll advances block.number (needed for governor state progression).
        //
        // vm.warp advances timestamp (not strictly needed for governor),
        // but it does not hurt and can help keep time consistent.
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Now voting should be active
        console.log("Proposal State: ", uint256(governor.state(proposalId))); // Active = 1
        assertEq(uint256(governor.state(proposalId)), 1);

        // ---------------------------------------------------------------------
        // 2) VOTE
        // ---------------------------------------------------------------------
        // Vote options in GovernorCountingSimple:
        // 0 = Against, 1 = For, 2 = Abstain
        uint8 voteWay = 1; // voting "For"
        string memory reason = "cuz blue frog is cool";

        // Vote as USER (the token holder)
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        // Advance to after voting period ends (BLOCKS)
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // If quorum is met and For > Against, state becomes Succeeded
        console.log("Proposal State: ", uint256(governor.state(proposalId))); // Succeeded = 4
        assertEq(uint256(governor.state(proposalId)), 4);

        // ---------------------------------------------------------------------
        // 3) QUEUE
        // ---------------------------------------------------------------------
        // queue requires the descriptionHash (not the full description)
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        // This schedules the operation in the timelock
        governor.queue(targets, values, calldatas, descriptionHash);

        // Timelock delay is in SECONDS, so vm.warp is the important part here.
        // vm.roll is not necessary for timelock, but ok.
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // After queueing and waiting minDelay, proposal should show as Queued (5)
        console.log("Proposal State: ", uint256(governor.state(proposalId))); // Queued = 5
        assertEq(uint256(governor.state(proposalId)), 5);

        // ---------------------------------------------------------------------
        // 4) EXECUTE
        // ---------------------------------------------------------------------
        // Executes the scheduled operation via the timelock
        governor.execute(targets, values, calldatas, descriptionHash);

        // After execution, state is Executed (7)
        console.log("Proposal State: ", uint256(governor.state(proposalId))); // Executed = 7
        assertEq(uint256(governor.state(proposalId)), 7);

        // Confirm Box was updated
        assertEq(box.getNumber(), valueToStore);
    }
}
