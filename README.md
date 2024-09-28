## Escrow Smart Contract

### Overview

This project implements an escrow smart contract using Solidity, providing a secure way for buyers and sellers to transact with both Ether and ERC20 tokens. The contract supports features such as dispute resolution and automatic fee calculation, ensuring that all parties are protected.

The contract is built using Solidity 0.8.13 and leverages the [Foundry](https://getfoundry.sh/) framework for testing and deployment.

### Features

- **Supports Both Ether and ERC20 Tokens:** Allows transactions using Ether or any ERC20 token.
- **Escrow Creation:** Buyers can create escrows, specifying the seller, arbitrator, payment token, and amount.
- **Dispute Handling:** Either the buyer or the seller can raise a dispute. The arbitrator can resolve disputes by releasing funds to either party.
- **Fee Calculation:** A fee is deducted from each transaction, which is configurable.
- **Time-Locked Withdrawals:** Sellers can withdraw funds after a specified period if no action is taken by the buyer.

### Prerequisites

- **Foundry:** Ensure you have [Foundry](https://getfoundry.sh/) installed on your system. You can install Foundry by running:
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```
- **Node.js & npm:** Required if you plan to use additional tools or plugins for smart contract development.

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/escrow-contract.git
   cd escrow-contract
   ```
2. Install dependencies:
   ```bash
   forge install
   ```

### Contract Structure

- **`Escrow.sol`:** The main contract file implementing the escrow logic. Includes functions for creating escrows, confirming deliveries, raising disputes, and handling fee calculations.
- **`TestToken.sol`:** A simple ERC20 token contract used for testing ERC20 functionalities in the escrow.
- **Tests:** Written using Foundry’s `forge-std` library to ensure comprehensive test coverage.

### Usage

1. **Create an Escrow:**

   - Buyers can create an escrow with either Ether or an ERC20 token:
     ```solidity
     function createEscrow(address _seller, address _arbitrator, address _token, uint256 _amount) public payable;
     ```
   - For Ether, pass `address(0)` as `_token` and send Ether using `msg.value`.

2. **Confirm Delivery:**

   - The buyer can confirm the delivery, releasing the funds to the seller:
     ```solidity
     function confirmDelivery(uint256 _transactionId) public;
     ```

3. **Raise a Dispute:**

   - Either the buyer or seller can raise a dispute if there is an issue:
     ```solidity
     function raiseDispute(uint256 _transactionId) public;
     ```

4. **Resolve a Dispute:**

   - The arbitrator can resolve the dispute, specifying whether to return the funds to the buyer or release them to the seller:
     ```solidity
     function resolveDispute(uint256 _transactionId, bool revertToBuyer) public;
     ```

5. **Withdraw After Expiry:**
   - The seller can withdraw funds if the transaction expires without action from the buyer:
     ```solidity
     function withdrawAfterExpiry(uint256 _transactionId) public;
     ```

### Testing

Tests are written using the Foundry framework. To run the tests, use:

```bash
forge test
```

### Test Cases Include:

- Creating an escrow with Ether and ERC20 tokens.
- Verifying the correct handling of disputes.
- Checking the fee calculation and distribution.
- Testing time-locked withdrawals by the seller.
- Edge cases, including invalid transactions and access control checks.

### Configuration

- **Fee Percentage:** The default fee percentage is set to `1%` (100 basis points). You can adjust this percentage directly in the contract or extend the contract to include a setter function.
- **Timeout Period:** The contract sets a 7-day timeout for the seller's withdrawal. This can be adjusted in the contract code.
