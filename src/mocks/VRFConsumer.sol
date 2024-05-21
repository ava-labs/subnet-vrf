// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

// import {IVRFProxy} from "../interfaces/IVRFProxy.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES UNAUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract VRFConsumer is VRFConsumerBaseV2 {
    mapping(address guesser => uint256 guess) public guesses;

    error AwaitingResolutionOfAPreviousGuess();

    /// vrfCoordinator in this case is our VRFProxy.
    constructor(address vrfCoordinator) VRFConsumerBaseV2(vrfCoordinator) {}

    receive() external payable {}

    function guessTheRandomNumber(uint256 guess) external {
        if (guesses[msg.sender] != 0) revert AwaitingResolutionOfAPreviousGuess();
        guesses[msg.sender] = guess;

        address proxy;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            proxy := sload(0x00)
        }

        // IVRFProxy(proxy).requestRandomWords(1);
    }

    // solhint-disable-next-line
    function fulfillRandomWords(uint256 vrfRequestID, uint256[] memory randomWords) internal override {}
}
