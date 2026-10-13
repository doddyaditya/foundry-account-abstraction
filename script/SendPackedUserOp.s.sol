//SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "../src/MinimalAccount.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

pragma solidity ^0.8.24;

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;
    address constant RANDOM_APPROVER = 0x87E579d724aEe0dfFd9D2cc4E5b2329D2f6dfDC0;

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        uint256 value = 0;
        address minimalAccount = DevOpsTools.get_most_recent_deployment("MinimalAccount", block.chainid);
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, RANDOM_APPROVER, 1e18);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, helperConfig.getConfig().usdc, value, functionData);
        PackedUserOperation memory userOp =
            createSignedUserOp(executeCallData, helperConfig.getConfig(), minimalAccount);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
        vm.stopBroadcast();
    }

    function createSignedUserOp(bytes memory callData, HelperConfig.NetworkConfig memory config, address minimalAccount)
        public
        view
        returns (PackedUserOperation memory)
    {
        //1. Generate unsigned PackedUserOperation
        uint256 nonce = IEntryPoint(config.entryPoint).getNonce(minimalAccount, 0);
        PackedUserOperation memory userOp = _createUnsignedUserOp(callData, minimalAccount, nonce);
        //2. Genereate userOpHash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        //3. Sign unsigned PackedUserOperation
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function _createUnsignedUserOp(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 preVerificationGas = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | uint256(preVerificationGas)),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | uint256(maxFeePerGas)),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
