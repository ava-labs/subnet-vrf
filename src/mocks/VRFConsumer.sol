// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract VRFConsumer is VRFConsumerBaseV2 {
    constructor(address vrfCoordinator) VRFConsumerBaseV2(vrfCoordinator) {}

    // solhint-disable-next-line
    function fulfillRandomWords(uint256 vrfRequestID, uint256[] memory randomWords) internal override {}
}
