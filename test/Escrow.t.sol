// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";
import {TestToken} from "../src/TestToken.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract EscrowTest is Test {
    Escrow public escrow;
    TestToken public token;
    address buyer = makeAddr("buyer");
    address seller = makeAddr("seller");
    address arbitrator = makeAddr("arbitrator");
    uint256 depositAmount = 1 ether;
    uint8 transactionId = 1;

    modifier runAsBuyer() {
        vm.startPrank(buyer, buyer);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        escrow = new Escrow();
        token = new TestToken(120e18);

        vm.deal(buyer, 15 ether);
        IERC20(token).transfer(buyer, 20e18);

        vm.prank(buyer);
        escrow.createEscrow{value: depositAmount}(seller, arbitrator, address(0), 0);
    }

    function testCreateEscrow() public runAsBuyer {
        escrow.createEscrow{value: depositAmount}(seller, arbitrator, address(0), 0);

        (
            address _buyer,
            address _seller,
            address _arbitrator,
            uint256 _amount,
            uint8 _state,
            address _token,
            uint256 timestamp
        ) = escrow.transactions(transactionId);

        assertEq(_buyer, buyer);
        assertEq(_seller, seller);
        assertEq(_arbitrator, arbitrator);
        assertEq(_amount, depositAmount);
        assertEq(_state, uint8(Escrow.EscrowState.PENDING));
        assertEq(_token, address(0));
    }

    function testCreateEscrowRevertsWithoutPayment() public runAsBuyer {
        vm.expectRevert(Escrow.DepositAmountZero.selector);
        escrow.createEscrow(seller, arbitrator, address(0), 0);
    }

    function testCreateEscrowWithERC20Token() public runAsBuyer {
        IERC20(token).approve(address(escrow), 1e18);
        escrow.createEscrow(seller, arbitrator, address(token), 1e18);

        uint256 balance = token.balanceOf(address(escrow));
        assertEq(balance, 1e18);
    }

    function testConfirmDelivery_TransactionNotFound() public {
        uint256 invalidTransactionId = 100;

        vm.expectRevert(Escrow.TransactionNotFound.selector);
        escrow.confirmDelivery(invalidTransactionId);
    }

    function testConfirmDelivery_TransactionAlreadyDelivered() public runAsBuyer {
        escrow.confirmDelivery(transactionId);

        vm.expectRevert(Escrow.InvalidTransactionState.selector);
        escrow.confirmDelivery(transactionId);
    }

    function testConfirmDelivery_OnlyTheBuyerCanConfirmDelivery() public {
        vm.prank(seller);
        vm.expectRevert(Escrow.OnlyBuyerCanConfirm.selector);
        escrow.confirmDelivery(transactionId);
    }

    function testConfirmDelivery_SuccessfullyDelivered() public runAsBuyer {
        escrow.confirmDelivery(transactionId);

        assertEq(seller.balance, 0.99 ether);
    }

    function testRaiseDispute_CannotWithdraw() public runAsBuyer {
        escrow.raiseDispute(transactionId);

        vm.expectRevert(Escrow.InvalidTransactionState.selector);
        escrow.confirmDelivery(transactionId);
    }

    function testRaiseDispute_ArbitratorCannotRaise() public {
        vm.prank(arbitrator);
        vm.expectRevert(Escrow.CannotRaiseDispute.selector);
        escrow.raiseDispute(transactionId);
    }

    function testResolveDispute_RevertToBuyer() public {
        vm.prank(buyer);
        escrow.raiseDispute(transactionId);

        vm.prank(arbitrator);
        escrow.resolveDispute(1, true);

        assertEq(address(escrow).balance, 0);
        assertEq(buyer.balance, 15 ether);
    }

    function testResolveDispute_RevertToSeller() public {
        vm.prank(buyer);
        escrow.raiseDispute(transactionId);

        vm.prank(arbitrator);
        escrow.resolveDispute(1, false);

        assertEq(address(escrow).balance, 0);
        assertEq(seller.balance, 1 ether);
    }

    function testResolveDispute_NotTheArbitrator() public {
        vm.prank(seller);

        vm.expectRevert(Escrow.NotTheArbitrator.selector);
        escrow.resolveDispute(1, true);
    }

    function testFeePercentageAfterConfirmDelivery() public runAsBuyer {
        escrow.confirmDelivery(transactionId);

        assertEq(escrow.feeAmount(), 0.01 ether);
    }

    function testWithdrawAfterExpiry_NotTheSeller() public {
        vm.expectRevert(Escrow.NotTheSeller.selector);
        escrow.withdrawAfterExpiry(transactionId);
    }

    function testWithdrawAfterExpiry_WithdrawalBeforeExpiry() public {
        vm.startPrank(seller);

        uint256 expirationTime = block.timestamp + 7 days;

        vm.warp(block.timestamp + 12 hours);

        vm.expectRevert(abi.encodeWithSelector(Escrow.WithdrawalBeforeExpiry.selector, block.timestamp, expirationTime));

        escrow.withdrawAfterExpiry(transactionId);
    }

    function testWithdrawAfterExpiry() public {
        vm.startPrank(seller);

        vm.warp(block.timestamp + 7 days);

        escrow.withdrawAfterExpiry(transactionId);
    }
}
