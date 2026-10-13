//SPDX-License-Identifier: MIT

import {Test} from "forge-std/Test.sol";
import {DeployMinimal} from "../script/DeployMinimal.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {MinimalAccount, SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../src/MinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {SendPackedUserOp, PackedUserOperation} from "../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

pragma solidity ^0.8.24;

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    uint256 constant AMOUNT = 1e18;
    SendPackedUserOp sendPackedUserOp;
    ERC20Mock usdc;
    address randomUser = makeAddr("randomUser");

    function setUp() external {
        DeployMinimal deployer = new DeployMinimal();
        (helperConfig, minimalAccount) = deployer.run();
        usdc = ERC20Mock(helperConfig.getConfig().usdc);
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() external {
        address owner = minimalAccount.owner();
        uint256 value = 0;
        vm.prank(owner);
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        minimalAccount.execute(address(usdc), value, data);
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() external {
        uint256 value = 0;
        vm.prank(randomUser);
        bytes memory data = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotEntryPointOrOwner.selector);
        minimalAccount.execute(address(usdc), value, data);
    }

    function testSignatureIsValid() external {
        address owner = minimalAccount.owner();
        uint256 value = 0;
        bytes memory callData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, address(usdc), value, callData);
        PackedUserOperation memory userOp =
            sendPackedUserOp.createSignedUserOp(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(userOp);
        address signer = ECDSA.recover(userOpHash.toEthSignedMessageHash(), userOp.signature);
        assertEq(signer, owner);
    }

    function testValidateUserOp() external {
        uint256 value = 0;
        bytes memory callData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, address(usdc), value, callData);
        PackedUserOperation memory userOp =
            sendPackedUserOp.createSignedUserOp(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(userOp);
        uint256 missingAccountFunds = 1e18;

        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(userOp, userOpHash, missingAccountFunds);
        assertEq(validationData, SIG_VALIDATION_SUCCESS);
    }

    function testEntryPointCanExecuteCommands() external {
        uint256 value = 0;
        bytes memory callData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, address(usdc), value, callData);
        PackedUserOperation memory userOp =
            sendPackedUserOp.createSignedUserOp(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.deal(address(minimalAccount), AMOUNT);

        vm.startBroadcast(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));
        vm.stopBroadcast();

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
