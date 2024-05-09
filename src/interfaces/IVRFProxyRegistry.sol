// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

interface IVRFProxyRegistry {
    event ProxyAdded(bytes32 indexed blockchainID, address indexed proxy);
    event ProxyRemoved(bytes32 indexed blockchainID, address indexed proxy);

    function isValid(bytes32 blockchainID, address proxy) external view returns (bool approved);

    function addProxies(bytes32 blockchainID, address[] calldata proxies) external;
    function removeProxies(bytes32 blockchainID, address[] calldata proxies) external;
}
