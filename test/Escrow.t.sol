// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";

contract EscrowTest is Test {
    Escrow public escrow;
    address buyer = makeAddr("buyer");
    address seller = makeAddr("seller");
    address arbitrator = makeAddr("arbitrator");
    uint256 depositAmount = 1 ether;

    modifier runAsBuyer() {
        vm.prank(buyer, buyer);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        escrow = new Escrow();

        vm.deal(buyer, 15 ether);

        vm.prank(buyer);
        escrow.createEscrow{value: depositAmount}(
            seller,
            arbitrator,
            address(0),
            0
        );
    }

    function testCreateEscrow() public {
        vm.prank(buyer);

        escrow.createEscrow{value: depositAmount}(
            seller,
            arbitrator,
            address(0),
            0
        );

        (
            address _buyer,
            address _seller,
            address _arbitrator,
            uint256 _amount,
            uint8 _state,
            address _token
        ) = escrow.transactions(1);

        assertEq(_buyer, buyer);
        assertEq(_seller, seller);
        assertEq(_arbitrator, arbitrator);
        assertEq(_amount, depositAmount);
        assertEq(_state, uint8(Escrow.EscrowState.PENDING));
        assertEq(_token, address(0));
    }

    function testCreateEscrowRevertsWithoutPayment() public {
        vm.prank(buyer);

        vm.expectRevert(Escrow.DepositAmountZero.selector);
        escrow.createEscrow{value: depositAmount}(
            seller,
            arbitrator,
            address(0),
            0
        );
    }

    function testConfirmDelivery_TransactionNotFound() public {
        uint256 invalidTransactionId = 100;

        vm.expectRevert(Escrow.TransactionNotFound.selector);
        escrow.confirmDelivery(invalidTransactionId);
    }

    function testConfirmDelivery_TransactionAlreadyDelivered() public {
        vm.prank(buyer);
        escrow.confirmDelivery(1);

        vm.prank(buyer);
        vm.expectRevert(Escrow.InvalidTransactionState.selector);
        escrow.confirmDelivery(1);
    }

    function testConfirmDelivery_OnlyTheBuyerCanConfirmDelivery() public {
        vm.prank(seller);
        vm.expectRevert(Escrow.OnlyBuyerCanConfirm.selector);
        escrow.confirmDelivery(1);
    }

    function testConfirmDelivery_SuccessfullyDelivered() public {
        vm.prank(buyer);
        escrow.confirmDelivery(1);

        assertEq(seller.balance, 0.99 ether);
    }

    function testRaiseDispute_CannotWithdraw() public {
        vm.prank(buyer);
        escrow.raiseDispute(1);

        vm.prank(buyer);
        vm.expectRevert(Escrow.InvalidTransactionState.selector);
        escrow.confirmDelivery(1);
    }

    function testRaiseDispute_ArbitratorCannotRaise() public {
        vm.prank(arbitrator);
        vm.expectRevert(Escrow.CannotRaiseDispute.selector);
        escrow.raiseDispute(1);
    }

    function testResolveDispute_RevertToBuyer() public {
        vm.prank(buyer);
        escrow.raiseDispute(1);

        vm.prank(arbitrator);
        escrow.resolveDispute(1, true);

        assertEq(address(escrow).balance, 0);
        assertEq(buyer.balance, 15 ether);
    }

    function testResolveDispute_RevertToSeller() public {
        vm.prank(buyer);
        escrow.raiseDispute(1);

        vm.prank(arbitrator);
        escrow.resolveDispute(1, false);

        assertEq(address(escrow).balance, 0);
        assertEq(seller.balance, 1 ether);
    }

    function testResolveDispute_NotArbitrator() public {
        vm.prank(seller);

        vm.expectRevert(Escrow.NotArbitrator.selector);
        escrow.resolveDispute(1, true);
    }

    function testFeePercentageAfterConfirmDelivery() public {
        vm.prank(buyer);
        escrow.confirmDelivery(1);

        assertEq(escrow.feeAmount(), 0.01 ether);
    }
}
