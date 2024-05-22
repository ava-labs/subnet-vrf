// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFProxy} from "../interfaces/IVRFProxy.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES UNAUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract VRFConsumer is VRFConsumerBaseV2 {
    struct Guess {
        address guesser;
        uint256 guess;
    }

    uint256 public constant REWARD_AMOUNT = 0.05 ether;
    mapping(uint256 vrfRequestID => Guess guess) public guesses;
    mapping(address guesser => uint256 amountToClaim) public rewards;

    event Payout(address guesser, uint256 reward);
    event Fund(address funder, uint256 total);

    /// vrfCoordinator in this case is our VRFProxy.
    constructor(address vrfCoordinator) VRFConsumerBaseV2(vrfCoordinator) {}

    receive() external payable {
        emit Fund(msg.sender, msg.value);
    }

    function guessTheRandomNumber(uint256 guess) external {
        address proxy;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            proxy := sload(0x00)
        }

        uint256 vrfRequestID = IVRFProxy(proxy).requestNonce() + 1;
        guesses[vrfRequestID] = Guess({guesser: msg.sender, guess: guess});

        IVRFProxy(proxy).requestRandomWords(1, 200_000, 1);
    }

    function claim() external {
        uint256 reward = rewards[msg.sender];
        if (reward != 0) {
            payable(msg.sender).transfer(reward);
            emit Payout(msg.sender, reward);
        }
    }

    // solhint-disable-next-line
    function fulfillRandomWords(uint256 vrfRequestID, uint256[] memory randomWords) internal override {
        Guess memory guess = guesses[vrfRequestID];
        if (randomWords[0] == guess.guess) {
            rewards[guess.guesser] += REWARD_AMOUNT;
        }
    }
}
