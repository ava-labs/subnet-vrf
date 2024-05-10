// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFConsumerRegistry} from "./interfaces/IVRFConsumerRegistry.sol";
import {AccessControl} from "@openzeppelin/contracts@4.8.1/access/AccessControl.sol";

contract VRFConsumerRegistry is IVRFConsumerRegistry, AccessControl {
    /**
     * @dev Mapping containing status of consumers, if they're approved to use the VRF Service or not
     */
    mapping(address consumer => bool approved) public isValid;

    /**
     * @dev Role which is has permission to add new consumers (but not to remove existing ones)
     */
    bytes32 public constant CONSUMER_MANAGER = keccak256("CONSUMER_MANAGER");

    constructor(address admin, address[] memory consumerManagers) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONSUMER_MANAGER, admin);
        uint256 length = consumerManagers.length; // gas opt
        for (uint256 i; i < length; i++) {
            _grantRole(CONSUMER_MANAGER, consumerManagers[i]);
        }
    }

    /**
     * @dev Function to whitelist consumers for usage of the VRF service
     */
    function addConsumers(address[] calldata consumers) external onlyRole(CONSUMER_MANAGER) {
        uint256 length = consumers.length; // gas opt
        for (uint256 i; i < length; i++) {
            address consumer = consumers[i];
            if (!isValid[consumer] && consumer != address(0)) {
                isValid[consumer] = true;
                emit ConsumerAdded(consumer);
            }
        }
    }

    /**
     * @dev Function to remove whitelisted consumers for usage of the VRF service
     */
    function removeConsumers(address[] calldata consumers) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = consumers.length; // gas opt
        for (uint256 i; i < length; i++) {
            address consumer = consumers[i];
            if (isValid[consumer] && consumer != address(0)) {
                delete isValid[consumer];
                emit ConsumerRemoved(consumer);
            }
        }
    }
}
