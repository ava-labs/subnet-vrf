// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IVRFProxyRegistry {
    event ProxyAdded(bytes32 indexed blockchainId, address indexed proxy);
    event ProxyRemoved(bytes32 indexed blockchainId, address indexed proxy);

    function isValid(bytes32 blockchainId, address proxy) external view returns (bool approved);

    function addProxies(bytes32 blockchainId, address[] calldata proxies) external;
    function removeProxies(bytes32 blockchainId, address[] calldata proxies) external;
}
