// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;
import "forge-std/Test.sol";
import {Chief} from "../src/Chief.sol";
import {MockTokenWithCallback} from "../src/MockTokenWithCallback.sol";

contract ChiefReentrancyTest is Test {
    Chief chief;
    MockTokenWithCallback token;
    address user = address(0xBEEF);

    function setUp() public {
        // Déploiement du Chief avec un mock token temporaire
        Chief tempChief = new Chief(address(0), 10, 0, 0);
        // Déploiement du mock token avec l'adresse du Chief
        token = new MockTokenWithCallback(address(tempChief));
        // Déploiement du Chief avec le bon mock token
        chief = new Chief(address(token), 10, 0, 0);
        // Mint des tokens au user sur le bon mock
        token.mint(user, 1 ether);
    }

    function testLockTriggersReentrancyCallback() public {
        // Simulate user approving Chief
        vm.startPrank(user);
        token.approve(address(chief), 1 ether);
        console.log("[TEST] Approve done");
        console.log("[TEST] User balance before lock: %s", token.balanceOf(user));
        console.log("[TEST] User deposits before lock: %s", chief.deposits(user));
        // Record all logs for event order
        vm.recordLogs();
        chief.lock(1 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundCallback;
        bool foundLock;
        uint256 callbackIndex;
        uint256 lockIndex;
        uint256 depositsBefore;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("ReentrantCallback(address,uint256,uint256)")) {
                foundCallback = true;
                callbackIndex = i;
                depositsBefore = abi.decode(entries[i].data, (uint256));
                console.log("[EVENT] ReentrantCallback, depositsBefore=%s", depositsBefore);
            }
            if (entries[i].topics[0] == keccak256("Lock(address,uint256)")) {
                foundLock = true;
                lockIndex = i;
                console.log("[EVENT] Lock");
            }
        }
        console.log("[TEST] User deposits after lock: %s", chief.deposits(user));
        // PoC assertions
        require(foundCallback, "Callback event not found");
        require(foundLock, "Lock event not found");
        require(callbackIndex < lockIndex, "Callback must happen before Lock (reentrancy)");
        require(depositsBefore == 0, "deposits[msg.sender] must be 0 before update");
    }
}
