// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.25;

import {IVRFProxyRegistry} from "./interfaces/IVRFProxyRegistry.sol";
import {AccessControl} from "@openzeppelin/contracts@5.0.2/access/AccessControl.sol";

/// @custom:security-contact security.alerts@nima.enterprises
contract VRFProxyRegistry is IVRFProxyRegistry, AccessControl {
    /// @inheritdoc IVRFProxyRegistry
    mapping(bytes32 blockchainID => mapping(address proxy => bool approved)) public isApprovedProxy;
    /// @inheritdoc IVRFProxyRegistry
    bytes32 public constant PROXY_MANAGER = keccak256("PROXY_MANAGER");

    constructor(address admin, address[] memory proxyManagers) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PROXY_MANAGER, admin);
        uint256 length = proxyManagers.length;
        for (uint256 i; i < length; ++i) {
            _grantRole(PROXY_MANAGER, proxyManagers[i]);
        }
    }

    /// @inheritdoc IVRFProxyRegistry
    function addProxies(bytes32 blockchainID, address[] calldata proxies) external onlyRole(PROXY_MANAGER) {
        if (blockchainID == bytes32(0)) revert InvalidBlockchainID();
        uint256 length = proxies.length;
        for (uint256 i; i < length; ++i) {
            address proxy = proxies[i];
            if (!isApprovedProxy[blockchainID][proxy] && proxy != address(0)) {
                isApprovedProxy[blockchainID][proxy] = true;
                emit ProxyAdded(blockchainID, proxy);
            }
        }
    }

    /// @inheritdoc IVRFProxyRegistry
    function removeProxies(bytes32 blockchainID, address[] calldata proxies) external onlyRole(PROXY_MANAGER) {
        if (blockchainID == bytes32(0)) revert InvalidBlockchainID();
        uint256 length = proxies.length;
        for (uint256 i; i < length; ++i) {
            address proxy = proxies[i];
            if (isApprovedProxy[blockchainID][proxy] && proxy != address(0)) {
                delete isApprovedProxy[blockchainID][proxy];
                emit ProxyRemoved(blockchainID, proxy);
            }
        }
    }
}
