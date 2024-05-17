// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

interface IVRFConsumerRegistry {
    /**
     * @dev Emitted when a new consumer is added.
     */
    event ConsumerAdded(address indexed consumer);
    /**
     * @dev Emitted when a consumer is removed.
     */
    event ConsumerRemoved(address indexed consumer);

    /**
     * @dev Function to check if consumer is allowed to use the service.
     */
    function isValid(address consumer) external view returns (bool approved);

    /**
     * @dev Function add consumers.
     */
    function addConsumers(address[] calldata consumers) external;
    /**
     * @dev Function to remove consumers.
     */
    function removeConsumers(address[] calldata consumers) external;
}
