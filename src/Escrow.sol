// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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
    }

    mapping(uint => Transaction) public transactions;
    mapping(address => mapping(uint => bool)) public deliveryConfirmed;
    uint public transactionCounter;
    uint256 feePercentage = 100;
    uint256 public feeAmount;
    address owner;

    event EscrowCreated(
        uint indexed transactionId,
        address indexed buyer,
        address indexed seller,
        address arbitrator,
        uint amount
    );

    error DepositAmountZero();
    error OnlyBuyerCanConfirm();
    error TransactionNotFound();
    error DisputeAlreadyRaised();
    error CannotRaiseDispute();
    error CannotResolveDispute();
    error InvalidTransactionState();
    error SendingFundsFailed();
    error NotArbitrator();
    error NotTheOwner();

    event FundsDeposited(uint indexed transactionId);
    event DeliveryConfirmed(uint indexed transactionId);
    event DisputeRaised(uint indexed transactionId);
    event DisputeResolved(uint indexed transactionId, bool releasedToSeller);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotTheOwner();
        _;
    }

    function createEscrow(
        address _seller,
        address _arbitrator,
        address _token,
        uint256 _amount
    ) public payable {
        transactionCounter++;

        if (_token == address(0) && msg.value == 0) {
            revert DepositAmountZero();
        } else {
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        }

        feeAmount += calculateFee(msg.value);

        transactions[transactionCounter] = Transaction(
            msg.sender,
            _seller,
            _arbitrator,
            msg.value,
            uint8(EscrowState.PENDING),
            _token
        );

        emit EscrowCreated(
            transactionCounter,
            msg.sender,
            _seller,
            _arbitrator,
            msg.value
        );
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
        if (msg.sender != t.arbitrator) revert NotArbitrator();
        if (t.state != uint8(EscrowState.DISPUTE))
            revert CannotResolveDispute();

        t.state = uint8(EscrowState.COMPLETE);

        if (revertToBuyer) {
            (bool sent, ) = t.buyer.call{value: t.amount}("");
            require(sent, "Transaction failed");
        } else {
            (bool sent, ) = t.seller.call{value: t.amount}("");
            require(sent, "Transaction failed");
        }
    }

    function withdraw() public onlyOwner nonReentrant {
        uint256 withdrawAmount = feeAmount;
        feeAmount = 0;

        (bool sent, ) = owner.call{value: withdrawAmount}("");
        if (!sent) revert SendingFundsFailed();
    }

    function _validateTransaction(
        Transaction storage t,
        address sender
    ) internal view {
        if (t.buyer == address(0)) revert TransactionNotFound();
        if (t.buyer != sender) revert OnlyBuyerCanConfirm();
        if (t.state != uint8(EscrowState.PENDING))
            revert InvalidTransactionState();
    }

    function _completeTransaction(Transaction storage t) internal {
        t.state = uint8(EscrowState.COMPLETE);

        uint256 amountAfterFee = t.amount - calculateFee(t.amount);

        (bool sent, ) = t.seller.call{value: amountAfterFee}("");
        if (!sent) revert SendingFundsFailed();
    }

    function calculateFee(uint256 amount) internal view returns (uint256) {
        return (amount * feePercentage) / 10000;
    }
}
