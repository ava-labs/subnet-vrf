// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.25;

import {IVRFProxy} from "../interfaces/IVRFProxy.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES UNAUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract VRFConsumer is VRFConsumerBaseV2Plus {
    struct Guess {
        address guesser;
        uint256 guess;
        bool isResolved;
    }

    IVRFProxy public proxy;
    mapping(uint256 vrfRequestID => Guess guess) public guesses;
    mapping(address guesser => uint256 amountToClaim) public rewards;

    uint256 public constant REWARD_AMOUNT = 0.05 ether;

    event Payout(address indexed guesser, uint256 reward);
    event Fund(address indexed funder, uint256 total);
    event NewGuess(address indexed guesser, uint256 guess, uint256 indexed vrfRequestID);

    error InvalidDataLength();
    error InvalidRequestID();
    error RequestAlreadyResolved();

    /// vrfCoordinator in this case is our VRFProxy.
    constructor(address vrfCoordinator) VRFConsumerBaseV2Plus(vrfCoordinator) {
        proxy = IVRFProxy(vrfCoordinator);
    }

    receive() external payable {
        emit Fund(msg.sender, msg.value);
    }

    function takeAGuess(uint256 guess) external {
        uint256 vrfRequestID = proxy.requestNonce() + 1;
        guesses[vrfRequestID] = Guess({guesser: msg.sender, guess: guess, isResolved: false});

        proxy.requestRandomWords(1, 200_000, 1);
        emit NewGuess(msg.sender, guess, vrfRequestID);
    }

    function claim() external {
        uint256 reward = rewards[msg.sender];
        if (reward != 0) {
            payable(msg.sender).transfer(reward);
            emit Payout(msg.sender, reward);
        }
    }

    // solhint-disable-next-line
    function fulfillRandomWords(uint256 vrfRequestID, uint256[] calldata randomWords) internal override {
        if (randomWords.length != 1) revert InvalidDataLength();
        Guess storage guess = guesses[vrfRequestID];
        if (guess.guesser == address(0)) revert InvalidRequestID();
        if (guess.isResolved) revert RequestAlreadyResolved();
        guess.isResolved = true;
        if (randomWords[0] == guess.guess) {
            rewards[guess.guesser] += REWARD_AMOUNT;
        }
    }
}
