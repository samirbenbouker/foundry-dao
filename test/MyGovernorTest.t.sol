// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "src/MyGovernor.sol";
import {Box} from "src/Box.sol";
import {TimeLock} from "src/TimeLock.sol";
import {GovToken} from "src/GovToken.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    TimeLock timelock;
    GovToken govToken;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] proposers;
    address[] executors;

    bytes[] calldatas;
    address[] targets;
    uint256[] values;

    uint256 public constant MIN_DELAY = 3600;
    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 50400;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.prank(USER);
        govToken.delegate(USER);

        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, address(this));

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdateBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // 1. propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // view the state
        console.log("Proposal State: ", uint256(governor.state(proposalId))); // Pending = 0

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State: ", uint256(governor.state(proposalId))); // Active = 1
        assertEq(uint256(governor.state(proposalId)), 1);

        // 2. Vote
        string memory reason = "cuz blue frog is cool";

        uint8 voteWay = 1; // voting for yes
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        console.log("Proposal State: ", uint256(governor.state(proposalId))); // Succeeded = 4
        assertEq(uint256(governor.state(proposalId)), 4);

        // 3. Queue the Tx
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        console.log("Proposal State: ", uint256(governor.state(proposalId))); //Queued, 5
        assertEq(uint256(governor.state(proposalId)), 5);

        // 4. execute
        governor.execute(targets, values, calldatas, descriptionHash);

        console.log("Proposal State: ", uint256(governor.state(proposalId))); //Executed, 7
        assertEq(uint256(governor.state(proposalId)), 7);
        assert(box.getNumber() == valueToStore);
    }
}
