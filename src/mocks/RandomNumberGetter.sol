// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.25;

import {IVRFProxy} from "../interfaces/IVRFProxy.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES UNAUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract RandomNumberGetter is VRFConsumerBaseV2Plus {

    struct RandomNumber {
        bool pending;
        uint256 number;
    }

    IVRFProxy public proxy;
    mapping(uint256 vrfRequestID => RandomNumber number) public numbers;

    /// vrfCoordinator in this case is our VRFProxy.
    constructor(address vrfCoordinator) VRFConsumerBaseV2Plus(vrfCoordinator) {
        proxy = IVRFProxy(vrfCoordinator);
    }

    function getRandomNumber() external {
        uint256 vrfRequestID = proxy.requestNonce() + 1;
        numbers[vrfRequestID].pending = true;
        proxy.requestRandomWords(1, 200_000, 1);
    }

    // solhint-disable-next-line
    function fulfillRandomWords(uint256 vrfRequestID, uint256[] calldata randomWords) internal override {
        numbers[vrfRequestID].number = randomWords[0] % 1000;
        numbers[vrfRequestID].pending = false;
    }
}
