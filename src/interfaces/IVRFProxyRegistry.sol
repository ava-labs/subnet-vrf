// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.25;

import {IAccessControl} from "@openzeppelin/contracts@5.0.2/access/IAccessControl.sol";

interface IVRFProxyRegistry is IAccessControl {
    /**
     * @dev Emitted when a new proxy is added.
     */
    event ProxyAdded(bytes32 indexed blockchainID, address indexed proxy);
    /**
     * @dev Emitted when a proxy is removed.
     */
    event ProxyRemoved(bytes32 indexed blockchainID, address indexed proxy);

    // Errors
    error InvalidBlockchainID();

    /**
     * @dev Function add proxies.
     */
    function addProxies(bytes32 blockchainID, address[] calldata proxies) external;
    /**
     * @dev Function remove proxies.
     */
    function removeProxies(bytes32 blockchainID, address[] calldata proxies) external;

    /**
     * @dev Mapping containing status of proxies, if they're approved to use the VRF Service or not (per blockchain)
     */
    function isApprovedProxy(bytes32 blockchainID, address proxy) external view returns (bool approved);

    /**
     * @dev Role which is has permission to add new proxies (but not to remove existing ones)
     */
    // solhint-disable-next-line
    function PROXY_MANAGER() external pure returns (bytes32 ROLE_HASH);
}
