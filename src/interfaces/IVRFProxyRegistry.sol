// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.25;

import {IAccessControl} from "@openzeppelin/contracts@5.0.2/access/IAccessControl.sol";

interface IVRFProxyRegistry is IAccessControl {
    /**
     * @dev Emitted when a new proxy is added.
     * @param blockchainID is an id of a network to which an added proxy is deployed.
     * @param proxy is an address of a newly added proxy, this proxy is now operable/authorized.
     */
    event ProxyAdded(bytes32 indexed blockchainID, address indexed proxy);
    /**
     * @dev Emitted when a proxy is removed.
     * @param blockchainID is an id of a network to which a removed proxy is deployed.
     * @param proxy is an address of a removed proxy, this proxy is no longer operable/authorized.
     */
    event ProxyRemoved(bytes32 indexed blockchainID, address indexed proxy);

    // Errors
    error InvalidBlockchainID();

    /**
     * @dev Function to add proxies.
     * @param blockchainID is an id of a blockchain to which proxies are deployed.
     * @param proxies is an array of proxy addresses to be authorized.
     */
    function addProxies(bytes32 blockchainID, address[] calldata proxies) external;
    /**
     * @dev Function to remove proxies.
     * @param blockchainID is an id of a blockchain to which proxies are deployed.
     * @param proxies is an array of proxy addresses to be removed from the set of authorized proxies.
     */
    function removeProxies(bytes32 blockchainID, address[] calldata proxies) external;

    /**
     * @dev Mapping containing status of proxies, if they're approved to use the VRF Service or not (per blockchain).
     * @param blockchainID is an id of a blockchain to which a proxy is deployed.
     * @param proxy is an address of which we check the status - if it is an authorized proxy or not.
     */
    function isApprovedProxy(bytes32 blockchainID, address proxy) external view returns (bool approved);

    /**
     * @dev Role which is has permission to add new proxies (but not to remove existing ones)
     */
    // solhint-disable-next-line
    function PROXY_MANAGER() external pure returns (bytes32 ROLE_HASH);
}
