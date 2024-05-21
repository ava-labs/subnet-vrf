// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFProxyRegistry} from "./interfaces/IVRFProxyRegistry.sol";
import {AccessControl} from "@openzeppelin/contracts@4.8.1/access/AccessControl.sol";

contract VRFProxyRegistry is IVRFProxyRegistry, AccessControl {
    /**
     * @dev Mapping containing status of proxies, if they're approved to use the VRF Service or not (per blockchain)
     */
    mapping(bytes32 blockchainID => mapping(address proxy => bool approved)) public isValid;

    /**
     * @dev Role which is has permission to add new proxies (but not to remove existing ones)
     */
    bytes32 public constant PROXY_MANAGER = keccak256("PROXY_MANAGER");

    constructor(address admin, address[] memory proxyManagers) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PROXY_MANAGER, admin);
        uint256 length = proxyManagers.length; // gas opt
        for (uint256 i; i < length; i++) {
            _grantRole(PROXY_MANAGER, proxyManagers[i]);
        }
    }

    /**
     * @dev Function to whitelist proxies per blockchain for usage of the VRF service
     */
    function addProxies(bytes32 blockchainID, address[] calldata proxies) external onlyRole(PROXY_MANAGER) {
        if (blockchainID == bytes32(0)) revert InvalidBlockchainID();
        uint256 length = proxies.length; // gas opt
        for (uint256 i; i < length; i++) {
            address proxy = proxies[i];
            if (!isValid[blockchainID][proxy] && proxy != address(0)) {
                isValid[blockchainID][proxy] = true;
                emit ProxyAdded(blockchainID, proxy);
            }
        }
    }

    /**
     * @dev Function to remove whitelisted proxies per blockchain for usage of the VRF service
     */
    function removeProxies(bytes32 blockchainID, address[] calldata proxies) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (blockchainID == bytes32(0)) revert InvalidBlockchainID();
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
