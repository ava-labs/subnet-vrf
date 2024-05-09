// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFConsumerRegistry} from "./interfaces/IVRFConsumerRegistry.sol";
import {Ownable} from "@openzeppelin/contracts@4.8.1/access/Ownable.sol";

contract VRFConsumerRegistry is IVRFConsumerRegistry, Ownable {

    mapping(address consumer => bool approved) public isValid;

    function addConsumers(address[] calldata consumers) external onlyOwner {
        uint256 length = consumers.length; // gas opt
        for (uint256 i; i < length; i++) {
            address consumer = consumers[i];
            if (!isValid[consumer] && consumer != address(0)) {
                isValid[consumer] = true;
                emit ConsumerAdded(consumer);
            }
        }
    }

    function removeConsumers(address[] calldata consumers) external onlyOwner {
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
