// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFConsumerRegistry} from "./interfaces/IVRFConsumerRegistry.sol";
import {AccessControl} from "@openzeppelin/contracts@4.8.1/access/AccessControl.sol";

contract VRFConsumerRegistry is IVRFConsumerRegistry, AccessControl {
    mapping(address consumer => bool approved) public isValid;

    bytes32 public constant CONSUMER_MANAGER = keccak256("CONSUMER_MANAGER");

    constructor(address admin, address[] memory consumerManagers) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONSUMER_MANAGER, admin);
        uint256 length = consumerManagers.length; // gas opt
        for (uint256 i; i < length; i++) {
            _grantRole(CONSUMER_MANAGER, consumerManagers[i]);
        }
    }

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
