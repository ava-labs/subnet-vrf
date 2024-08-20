// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {IVRFProxyRegistry, VRFProxyRegistry} from "../VRFProxyRegistry.sol";

contract VRFProxyRegistryTest is Test {
    bytes32 public constant MOCK_VRF_PROXY_BLOCKCHAIN_ID =
        bytes32(hex"1234567812345678123456781234567812345678123456781234567812345678");
    address public constant MOCK_VRF_PROXY_ADDRESS = address(0x4444);

    address[] public managers;
    address[] public proxies;

    VRFProxyRegistry public vrfProxyRegistry;

    // Event emitted by VRFProxyRegistry
    event ProxyAdded(bytes32 indexed blockchainID, address indexed proxy);
    event ProxyRemoved(bytes32 indexed blockchainID, address indexed proxy);

    function setUp() public virtual {
        managers = new address[](1);
        managers[0] = address(this);
        proxies = new address[](1);
        proxies[0] = MOCK_VRF_PROXY_ADDRESS;

        vrfProxyRegistry = new VRFProxyRegistry(address(this), managers);
        vrfProxyRegistry.addProxies(MOCK_VRF_PROXY_BLOCKCHAIN_ID, proxies);
    }

    function testAddProxiesSuccess() public {
        proxies = new address[](1);
        proxies[0] = address(0x5555);
        vm.expectEmit(true, true, true, true, address(vrfProxyRegistry));
        emit ProxyAdded(MOCK_VRF_PROXY_BLOCKCHAIN_ID, proxies[0]);
        vrfProxyRegistry.addProxies(MOCK_VRF_PROXY_BLOCKCHAIN_ID, proxies);
    }

    function testFailToAddProxiesDueToInvalidBlockchainID() public {
        bytes4 expectedSelector = IVRFProxyRegistry.InvalidBlockchainID.selector;
        assertEq(expectedSelector, "0x6b1b9f5d");
        
        proxies = new address[](1);
        proxies[0] = address(0x5555);
        vm.expectRevert("0x6b1b9f5d");
        vrfProxyRegistry.addProxies(bytes32(0), proxies);
    }

    function testRemoveProxiesSuccess() public {
        proxies = new address[](1);
        proxies[0] = address(0x5555);
        vrfProxyRegistry.addProxies(MOCK_VRF_PROXY_BLOCKCHAIN_ID, proxies);
        vm.expectEmit(true, true, true, true, address(vrfProxyRegistry));
        emit ProxyRemoved(MOCK_VRF_PROXY_BLOCKCHAIN_ID, address(0x5555));
        vrfProxyRegistry.removeProxies(MOCK_VRF_PROXY_BLOCKCHAIN_ID, proxies);
    }

    function testFailToRemoveProxiesDueToInvalidBlockchainID() public {
        bytes4 expectedSelector = IVRFProxyRegistry.InvalidBlockchainID.selector;
        assertEq(expectedSelector, "0x6b1b9f5d");

        proxies = new address[](1);
        proxies[0] = address(0x5555);
        vm.expectRevert("0x6b1b9f5d");
        vrfProxyRegistry.removeProxies(bytes32(0), proxies);
    }
}
