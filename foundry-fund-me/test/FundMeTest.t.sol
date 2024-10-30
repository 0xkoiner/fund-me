// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    uint256 public constant AMOUNT_ETH = 3e18;
    address USER = makeAddr("user");
    uint256 public constant USER_BALANCE = 10 ether;

    modifier Funded() {
        vm.prank(USER);
        fundMe.fund{value: AMOUNT_ETH}();
        _;
    }

    function setUp() external {
        // fundMe = new FundMe(
        //     address(0x694AA1769357215DE4FAC081bf1f309aDC325306)
        // );
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, USER_BALANCE);
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testVersion() public view {
        assertEq(fundMe.getVersion(), 4);
    }

    function testFundFailWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public Funded {
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, AMOUNT_ETH);
    }

    function testAddsFunderToArrayOfFunders() public Funded {
        address funder = fundMe.getFunder(0);
        assertEq(USER, funder);
    }

    function testWithdrawAssetsOnlyOwnerAssertNotOwner() public Funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithDrawWithOwner() public Funded {
        uint256 ownerStartedBalance = fundMe.getOwner().balance;
        uint256 fundMeStartedBalance = address(fundMe).balance;

        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        uint256 ownerEndedBalance = fundMe.getOwner().balance;
        uint256 fundMeEndedBalance = address(fundMe).balance;

        assertNotEq(ownerStartedBalance, ownerEndedBalance);
        assertNotEq(fundMeStartedBalance, fundMeEndedBalance);

        assertEq(fundMeEndedBalance, 0);
        console.log(ownerStartedBalance + fundMeEndedBalance);
        console.log(ownerEndedBalance);

        assertEq(ownerStartedBalance + fundMeStartedBalance, ownerEndedBalance);
    }

    function testWithdrawOwnerFromMultiUsersFunded() public Funded {
        uint160 numbersOfUsers = 10;
        uint160 startingIndex = 1;

        for (uint160 i = startingIndex; i < numbersOfUsers; i++) {
            hoax(address(i), USER_BALANCE);
            fundMe.fund{value: AMOUNT_ETH}();
        }

        uint256 ownerStartedBalance = fundMe.getOwner().balance;
        uint256 fundMeStartedBalance = address(fundMe).balance;

        uint256 gasStart = gasleft();
        vm.txGasPrice(1);
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;

        console.log(gasUsed);

        uint256 ownerEndedBalance = fundMe.getOwner().balance;
        uint256 fundMeEndedBalance = address(fundMe).balance;

        assertNotEq(ownerStartedBalance, ownerEndedBalance);
        assertNotEq(fundMeStartedBalance, fundMeEndedBalance);

        assertEq(fundMeEndedBalance, 0);
        assertEq(ownerStartedBalance + fundMeStartedBalance, ownerEndedBalance);
    }
}
