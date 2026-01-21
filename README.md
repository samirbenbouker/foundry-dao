
# 🏛️ DAO Governance with OpenZeppelin

This project implements a **complete on-chain governance system** using
**OpenZeppelin Contracts v5** and **Foundry**.

It demonstrates how a DAO can safely control smart contracts through:
- token-based voting
- proposal lifecycle management
- and delayed execution via a timelock

This is the same architecture used by real-world DAOs.

---

## 📦 Architecture

```

GovToken (ERC20Votes)
│
▼
MyGovernor (proposals + voting)
│
▼
TimeLock (delay + execution)
│
▼
Box (governance-controlled contract)

````

All state changes in `Box` must go through governance.

---

## 🧱 Contracts

### `GovToken.sol`
- ERC20 governance token
- Uses `ERC20Votes`
- Voting power requires delegation
- Snapshot-based voting

> `mint()` is public for testing purposes only

---

### `MyGovernor.sol`
- OpenZeppelin Governor with:
  - block-based voting delay & period
  - simple vote counting (For / Against / Abstain)
  - quorum as a percentage of total supply
  - timelock integration

**Configuration**
- Voting delay: 1 block  
- Voting period: 50400 blocks  
- Proposal threshold: 0  
- Quorum: 4%

---

### `TimeLock.sol`
- Wrapper around `TimelockController`
- Enforces a minimum execution delay
- Roles:
  - Governor → proposer
  - Anyone → executor
  - Admin role revoked after setup

---

### `Box.sol`
- Simple storage contract
- Uses `Ownable`
- Ownership transferred to the timelock
- Can only be modified via governance

---

## 🔄 Governance Flow

1. Token holder delegates voting power
2. Proposal is created
3. Voting starts after the delay
4. Token holders vote
5. Proposal succeeds if quorum is met
6. Proposal is queued in the timelock
7. After the delay, proposal is executed
8. Target contract state is updated

---

## 🧪 Tests

The test suite verifies the **full governance lifecycle**:
- direct calls to `Box` revert
- proposal creation
- voting with delegated tokens
- correct state transitions
- timelock queueing and execution

Run tests with:

```bash
forge test -vv
````

---

## 🔐 Security Model

* No direct access to governed contracts
* All executions go through a timelock
* Mandatory execution delay
* Snapshot-based voting power
* Permissionless execution

---

## 📌 Notes

This project is intended for **learning and demonstration purposes**.
Production systems require additional safeguards and audits.

If you understand this project, you understand how modern DAO governance works.
