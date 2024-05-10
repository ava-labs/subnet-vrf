// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

interface IVRFProxyRegistry {
    /**
     * @dev Emitted when a new proxy is added.
     */
    event ProxyAdded(bytes32 indexed blockchainID, address indexed proxy);
    /**
     * @dev Emitted when a proxy is removed.
     */
    event ProxyRemoved(bytes32 indexed blockchainID, address indexed proxy);

    /**
     * @dev Function to check if a proxy from a specific blockchain is approved to call the provider contract.
     */
    function isValid(bytes32 blockchainID, address proxy) external view returns (bool approved);

    /**
     * @dev Function add proxies.
     */
    function addProxies(bytes32 blockchainID, address[] calldata proxies) external;
    /**
     * @dev Function remove proxies.
     */
    function removeProxies(bytes32 blockchainID, address[] calldata proxies) external;
}
