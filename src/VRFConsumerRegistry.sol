// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFConsumerRegistry} from "./interfaces/IVRFConsumerRegistry.sol";
import {AccessControl} from "@openzeppelin/contracts@4.8.1/access/AccessControl.sol";

contract VRFConsumerRegistry is IVRFConsumerRegistry, AccessControl {
    /// @inheritdoc IVRFConsumerRegistry
    mapping(address consumer => bool isApproved) public isApprovedConsumer;

    /// @inheritdoc IVRFConsumerRegistry
    bytes32 public constant CONSUMER_MANAGER = keccak256("CONSUMER_MANAGER");

    constructor(address admin, address[] memory consumerManagers) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONSUMER_MANAGER, admin);
        uint256 length = consumerManagers.length;
        for (uint256 i; i < length; ++i) {
            _grantRole(CONSUMER_MANAGER, consumerManagers[i]);
        }
    }

    /// @inheritdoc IVRFConsumerRegistry
    function addConsumers(address[] calldata consumers) external onlyRole(CONSUMER_MANAGER) {
        uint256 length = consumers.length;
        for (uint256 i; i < length; ++i) {
            address consumer = consumers[i];
            if (!isApprovedConsumer[consumer] && consumer != address(0)) {
                isApprovedConsumer[consumer] = true;
                emit ConsumerAdded(consumer);
            }
        }
    }

    /// @inheritdoc IVRFConsumerRegistry
    function removeConsumers(address[] calldata consumers) external onlyRole(CONSUMER_MANAGER) {
        uint256 length = consumers.length;
        for (uint256 i; i < length; ++i) {
            address consumer = consumers[i];
            if (isApprovedConsumer[consumer] && consumer != address(0)) {
                delete isApprovedConsumer[consumer];
                emit ConsumerRemoved(consumer);
            }
        }
    }
}
