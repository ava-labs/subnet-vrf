// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IVRFConsumerRegistry {
    event ConsumerAdded(address indexed consumer);
    event ConsumerRemoved(address indexed consumer);

    function isValid(address consumer) external view returns (bool approved);

    function addConsumers(address[] calldata consumers) external;
    function removeConsumers(address[] calldata consumers) external;
}
