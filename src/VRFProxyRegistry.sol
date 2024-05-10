// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFProxyRegistry} from "./interfaces/IVRFProxyRegistry.sol";
import {AccessControl} from "@openzeppelin/contracts@4.8.1/access/AccessControl.sol";

contract VRFProxyRegistry is IVRFProxyRegistry, AccessControl {

    mapping(bytes32 blockchainID => mapping(address proxy => bool approved)) public isValid;

    bytes32 public constant PROXY_MANAGER = keccak256("PROXY_MANAGER");

    constructor(
        address admin,
        address[] memory proxyManagers
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PROXY_MANAGER, admin);
        uint256 length = proxyManagers.length; // gas opt
        for (uint256 i; i < length; i++) {
            _grantRole(PROXY_MANAGER, proxyManagers[i]);
        }
    }

    function addProxies(bytes32 blockchainID, address[] calldata proxies) external onlyRole(PROXY_MANAGER) {
        if (blockchainID == bytes32(0)) revert();
        uint256 length = proxies.length; // gas opt
        for (uint256 i; i < length; i++) {
            address proxy = proxies[i];
            if (!isValid[blockchainID][proxy] && proxy != address(0)) {
                isValid[blockchainID][proxy] = true;
                emit ProxyAdded(blockchainID, proxy);
            }
        }
    }

    function removeProxies(bytes32 blockchainID, address[] calldata proxies) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (blockchainID == bytes32(0)) revert();
        uint256 length = proxies.length; // gas opt
        for (uint256 i; i < length; i++) {
            address proxy = proxies[i];
            if (isValid[blockchainID][proxy] && proxy != address(0)) {
                delete isValid[blockchainID][proxy];
                emit ProxyRemoved(blockchainID, proxy);
            }
        }
    }
}
