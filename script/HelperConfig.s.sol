//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_CHAIN_ID = 421614;
    uint256 constant ZKSYNC_CHAIN_ID = 300;
    uint256 constant ANVIL_CHAIN_ID = 31337;
    address constant SEPOLIA_ENTRYPOINT_ADDRESS = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant BURNER_WALLET = 0xa7D069b1bA1bc4ef9298d88A6a3Ff39e6a4e58cd;

    NetworkConfig localNetworkConfig;
    mapping(uint256 => NetworkConfig) networkConfigs;

    struct NetworkConfig {
        address entryPoint;
        address account;
        address usdc;
    }

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_CHAIN_ID] = getZkSyncSepoliaConfig();
        networkConfigs[ARBITRUM_CHAIN_ID] = getArbitrumSepoliaConfig();
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: SEPOLIA_ENTRYPOINT_ADDRESS,
            account: BURNER_WALLET,
            usdc: 0x53844F9577C2334e541Aec7Df7174ECe5dF1fCf0
        });
    }

    function getArbitrumSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: SEPOLIA_ENTRYPOINT_ADDRESS,
            account: BURNER_WALLET,
            usdc: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
        });
    }

    function getZkSyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0), account: BURNER_WALLET, usdc: 0x5A7d6b2F92C77FAD6CCaBd7EE0624E64907Eaf3E
        });
    }

    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        console2.log("Deploying ERC20Mock...");
        ERC20Mock usdc = new ERC20Mock();
        console2.log("Deployed");

        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();
        localNetworkConfig =
            NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_ACCOUNT, usdc: address(usdc)});
        return localNetworkConfig;
    }

    function getNetworkConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == ANVIL_CHAIN_ID) {
            return getOrCreateAnvilNetworkConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        }
        revert HelperConfig__InvalidChainId();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getNetworkConfigByChainId(block.chainid);
    }
}
