// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract Escrow is ReentrancyGuard {
    enum EscrowState {
        AWAITING_PAYMENT,
        PENDING,
        COMPLETE,
        DISPUTE
    }

    struct Transaction {
        address buyer;
        address seller;
        address arbitrator;
        uint256 amount;
        uint8 state;
        address token; // Address of ERC20 token or address(0) for Ether
        uint256 timestamp;
    }

    mapping(address => uint256) public tokenFeeAmounts;
    mapping(uint256 => Transaction) public transactions;
    mapping(address => mapping(uint256 => bool)) public deliveryConfirmed;

    uint256 feePercentage = 100;
    uint256 public transactionCounter;
    uint256 public feeAmount;

    error NotTheSeller();
    error NotTheArbitrator();
    error DepositAmountZero();
    error CannotRaiseDispute();
    error SendingFundsFailed();
    error OnlyBuyerCanConfirm();
    error TransactionNotFound();
    error CannotResolveDispute();
    error DisputeAlreadyRaised();
    error InvalidTransactionState();
    error WithdrawalBeforeExpiry(uint256 currentTimestamp, uint256 expiryTime);

    event EscrowCreated(
        uint256 indexed transactionId, address indexed buyer, address indexed seller, address arbitrator, uint256 amount
    );
    event DisputeResolved(uint256 indexed transactionId, bool releasedToSeller);
    event DeliveryConfirmed(uint256 indexed transactionId);
    event FundsDeposited(uint256 indexed transactionId);
    event DisputeRaised(uint256 indexed transactionId);

    function createEscrow(address _seller, address _arbitrator, address _token, uint256 _amount) public payable {
        transactionCounter++;

        if (_token == address(0)) {
            if (msg.value == 0) revert DepositAmountZero();
            _amount = msg.value;
        } else {
            _sendFunds(address(this), _amount, _token);
        }

        feeAmount += _calculateFee(_amount);

        transactions[transactionCounter] = Transaction(
            msg.sender, _seller, _arbitrator, _amount, uint8(EscrowState.PENDING), _token, block.timestamp + 7 days
        );

        emit EscrowCreated(transactionCounter, msg.sender, _seller, _arbitrator, _amount);
    }

    function confirmDelivery(uint256 _transactionId) public {
        Transaction storage t = transactions[_transactionId];

        _validateTransaction(t, msg.sender);

        _completeTransaction(t);
    }

    function raiseDispute(uint256 _transactionId) public {
        Transaction storage t = transactions[_transactionId];

        if (t.buyer == msg.sender || t.seller == msg.sender) {
            t.state = uint8(EscrowState.DISPUTE);
        } else {
            revert CannotRaiseDispute();
        }
    }

    function resolveDispute(uint256 _transactionId, bool revertToBuyer) public {
        Transaction storage t = transactions[_transactionId];
        if (msg.sender != t.arbitrator) revert NotTheArbitrator();
        if (t.state != uint8(EscrowState.DISPUTE)) {
            revert CannotResolveDispute();
        }

        t.state = uint8(EscrowState.COMPLETE);

        _sendFunds(revertToBuyer ? t.buyer : t.seller, t.amount, t.token);
    }

    function withdrawAfterExpiry(uint256 _transactionId) public {
        Transaction storage t = transactions[_transactionId];

        if (t.seller != msg.sender) revert NotTheSeller();
        if (block.timestamp < t.timestamp) {
            revert WithdrawalBeforeExpiry(block.timestamp, t.timestamp);
        }

        _completeTransaction(t);
    }

    function _validateTransaction(Transaction storage t, address sender) internal view {
        if (t.buyer == address(0)) revert TransactionNotFound();
        if (t.buyer != sender) revert OnlyBuyerCanConfirm();
        if (t.state != uint8(EscrowState.PENDING)) {
            revert InvalidTransactionState();
        }
    }

    function _completeTransaction(Transaction storage t) internal {
        t.state = uint8(EscrowState.COMPLETE);

        uint256 amountAfterFee = t.amount - _calculateFee(t.amount);

        (bool sent,) = t.seller.call{value: amountAfterFee}("");
        if (!sent) revert SendingFundsFailed();
    }

    function _calculateFee(uint256 amount) internal view returns (uint256) {
        return (amount * feePercentage) / 10000;
    }

    function _sendFunds(address recipient, uint256 amount, address token) internal {
        if (token == address(0)) {
            // Handle Ether transfer
            (bool sent,) = recipient.call{value: amount}("");
            if (!sent) revert SendingFundsFailed();
        } else {
            // Handle ERC20 token transfer
            IERC20(token).transferFrom(msg.sender, recipient, amount);
        }
    }
}
