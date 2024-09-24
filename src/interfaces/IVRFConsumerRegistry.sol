// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IAccessControl} from "@openzeppelin/contracts@4.8.1/access/IAccessControl.sol";

interface IVRFConsumerRegistry is IAccessControl {
    /**
     * @dev Emitted when a new consumer is added.
     * @param consumer is an address of a newly added consumer.
     */
    event ConsumerAdded(address indexed consumer);
    /**
     * @dev Emitted when a consumer is removed.
     * @param consumer is an address of a removed consumer.
     */
    event ConsumerRemoved(address indexed consumer);

    /**
     * @dev Function to add consumers.
     * @param consumers is an array of consumers to be added.
     */
    function addConsumers(address[] calldata consumers) external;
    /**
     * @dev Function to remove consumers.
     * @param consumers is an array of consumers to be removed.
     */
    function removeConsumers(address[] calldata consumers) external;

    /**
     * @dev Mapping containing status of consumers, if they're approved to use the VRF Service or not
     * @param consumer is an address to check status of - if it is an approved consumer or not
     */
    function isApprovedConsumer(address consumer) external view returns (bool approved);

    /**
     * @dev Role which is has permission to add new consumers (but not to remove existing ones)
     */
    // solhint-disable-next-line
    function CONSUMER_MANAGER() external pure returns (bytes32 ROLE_HASH);
}
