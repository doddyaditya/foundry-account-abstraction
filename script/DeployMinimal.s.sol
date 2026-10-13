//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract DeployMinimal is Script {
    function run() external returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        vm.startBroadcast(helperConfig.getConfig().account);
        MinimalAccount minimalAccount = new MinimalAccount(helperConfig.getConfig().entryPoint);
        minimalAccount.transferOwnership(helperConfig.getConfig().account);
        vm.stopBroadcast();
        return (helperConfig, minimalAccount);
    }
}
