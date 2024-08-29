// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IAccessControl} from "@openzeppelin/contracts@4.8.1/access/IAccessControl.sol";

interface IVRFProxyRegistry is IAccessControl {
    /**
     * @dev Emitted when defaultProxyAllowance value is set.
     */
    event DefaultProxyAllowanceSet(uint256 defaultProxyAllowance);
    /**
     * @dev Emitted when proxy specific allowance value is set.
     * @param blockchainID is the id of a blockchain where proxy is deployed.
     * @param proxy is an address of a proxy.
     * @param allowance is newly set allowance value.
     */
    event ProxyAllowanceSet(bytes32 blockchainID, address proxy, uint256 allowance);
    /**
     * @dev Emitted when a new proxy is added.
     */
    event ProxyAdded(bytes32 indexed blockchainID, address indexed proxy, uint256 initialAllowance);
    /**
     * @dev Emitted when a proxy is removed.
     */
    event ProxyRemoved(bytes32 indexed blockchainID, address indexed proxy);

    // Errors
    error InvalidBlockchainID();
    error ArrayLengthMismatch();
    error UnauthorizedProxy(address proxy);

    /**
     * @dev Function add proxies.
     */
    function addProxies(bytes32 blockchainID, address[] calldata proxies, uint256[] calldata allowances) external;
    /**
     * @dev Function remove proxies.
     */
    function removeProxies(bytes32 blockchainID, address[] calldata proxies) external;

    /**
     * @dev Mapping containing status of proxies, if they're approved to use the VRF Service or not (per blockchain)
     */
    function isApprovedProxy(bytes32 blockchainID, address proxy) external view returns (bool approved);

    /**
     * @dev Variable containing default daily $LINK allowance for authorized proxies.
     */
    function defaultProxyAllowance() external view returns (uint256);

    /**
     * @dev Function to set the default proxy allowance value.
     * @param defaultProxyAllowance_ is a new value to be set as defaultProxyAllowance.
     */
    function setDefaultProxyAllowance(uint256 defaultProxyAllowance_) external;

    /**
     * @dev Function to override allowance for a certain set of proxies.
     * @param blockchainID is an id of a network to which proxies are deployed.
     * @param proxies is a set of proxies to override allowance for.
     * @param allowances is a set of allowances to set for each specified proxy in the order of input.
     */
    function setProxyAllowances(bytes32 blockchainID, address[] calldata proxies, uint256[] calldata allowances)
        external;

    /**
     * @dev Function to retrieve allowance value of a specified proxy.
     * @param blockchainID is the id of a blockchain where proxy is deployed.
     * @param proxy is an address of a proxy.
     */
    function getProxyAllowance(bytes32 blockchainID, address proxy) external view returns (uint256 allowance);

    /**
     * @dev Role which is has permission to add new proxies (but not to remove existing ones)
     */
    // solhint-disable-next-line
    function PROXY_MANAGER() external pure returns (bytes32 ROLE_HASH);
}
