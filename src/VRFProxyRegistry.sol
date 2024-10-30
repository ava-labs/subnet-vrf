// (c) 2024, Ava Labs, Inc. All rights reserved.
// SPDX-License-Identifier: LicenseRef-AvaLabsProprietary

// This code is licensed under a custom license.
// See the file LICENSE for licensing terms.

pragma solidity 0.8.25;

import {IVRFProxyRegistry} from "./interfaces/IVRFProxyRegistry.sol";
import {AccessControl} from "@openzeppelin/contracts@5.0.2/access/AccessControl.sol";

/// @custom:security-contact security.alerts@nima.enterprises
contract VRFProxyRegistry is IVRFProxyRegistry, AccessControl {
    /// @inheritdoc IVRFProxyRegistry
    uint256 public defaultProxyAllowance = 15e18;
    /// @inheritdoc IVRFProxyRegistry
    mapping(bytes32 blockchainID => mapping(address proxy => bool approved)) public isApprovedProxy;
    /**
     * @dev Mapping containing allowances of proxies, if allowance value for a proxy is zero - the default value will be used.
     * @dev Allowance parameter overrides defaultProxyAllowance for a certain proxy,
     * if allowance is not set (or is set to 0) - then the default allowance will be applied.
     */
    mapping(bytes32 blockchainID => mapping(address proxy => uint256 allowance)) private _proxyAllowances;
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
    function setDefaultProxyAllowance(uint256 defaultProxyAllowance_) external onlyRole(PROXY_MANAGER) {
        defaultProxyAllowance = defaultProxyAllowance_;
        emit DefaultProxyAllowanceSet(defaultProxyAllowance_);
    }

    /// @inheritdoc IVRFProxyRegistry
    function setProxyAllowances(bytes32 blockchainID, address[] calldata proxies, uint256[] calldata allowances)
        external
        onlyRole(PROXY_MANAGER)
    {
        // Gas optimization.
        uint256 length = proxies.length;
        uint256 dpa = defaultProxyAllowance;
        // Revert on array mismatch.
        if (length != allowances.length) revert ArrayLengthMismatch();
        for (uint256 i; i < length; ++i) {
            // Gas optimization.
            address proxy = proxies[i];
            uint256 allowance = allowances[i];
            // Ensure proxy being approved for interaction with VRFProvider.
            if (!isApprovedProxy[blockchainID][proxy]) {
                revert UnauthorizedProxy(blockchainID, proxy);
            }
            // Set new allowance value.
            _proxyAllowances[blockchainID][proxy] = allowance;
            emit ProxyAllowanceSet(blockchainID, proxy, allowance == 0 ? dpa : allowance);
        }
    }

    /// @inheritdoc IVRFProxyRegistry
    function addProxies(bytes32 blockchainID, address[] calldata proxies, uint256[] calldata allowances)
        external
        onlyRole(PROXY_MANAGER)
    {
        if (blockchainID == bytes32(0)) revert InvalidBlockchainID();
        uint256 length = proxies.length;
        uint256 dpa = defaultProxyAllowance;
        // Revert on array mismatch.
        if (length != allowances.length) revert ArrayLengthMismatch();
        for (uint256 i; i < length; i++) {
            address proxy = proxies[i];
            if (!isApprovedProxy[blockchainID][proxy] && proxy != address(0)) {
                uint256 allowance = allowances[i];
                isApprovedProxy[blockchainID][proxy] = true;
                if (allowance > 0) _proxyAllowances[blockchainID][proxy] = allowance;
                emit ProxyAdded(blockchainID, proxy, allowance == 0 ? dpa : allowance);
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
                delete _proxyAllowances[blockchainID][proxy];
                emit ProxyRemoved(blockchainID, proxy);
            }
        }
    }

    /// @inheritdoc IVRFProxyRegistry
    function getProxyAllowance(bytes32 blockchainID, address proxy) external view returns (uint256) {
        uint256 allowance = _proxyAllowances[blockchainID][proxy];
        return allowance != 0 ? allowance : defaultProxyAllowance;
    }
}
