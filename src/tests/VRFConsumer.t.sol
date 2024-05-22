// SPDX-License-Identifier: Ecosystem

pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {VRFConsumer} from "../mocks/VRFConsumer.sol";
import {IVRFProxy} from "../interfaces/IVRFProxy.sol";

contract SimpleBettingGameTest is Test {
    VRFConsumer public consumer;
    address public constant MOCK_VRF_COORDINATOR = address(0xabcd);

    event Payout(address indexed guesser, uint256 reward);
    event Fund(address indexed funder, uint256 total);
    event NewGuess(address indexed guesser, uint256 guess, uint256 indexed vrfRequestID);

    function setUp() public virtual {
        consumer = new VRFConsumer(MOCK_VRF_COORDINATOR);
    }

    function testTakeAGuessSuccess() public {
        uint256 expectedRequestId = 1;
        uint32 number = 99;
        vm.expectEmit(true, true, true, true, address(consumer));
        emit NewGuess(address(this), number, expectedRequestId);

        vm.mockCall(MOCK_VRF_COORDINATOR, abi.encodeWithSelector(IVRFProxy.requestNonce.selector), abi.encode(0));
        vm.expectCall(MOCK_VRF_COORDINATOR, abi.encodeWithSelector(IVRFProxy.requestNonce.selector));
        vm.mockCall(MOCK_VRF_COORDINATOR, abi.encodeWithSelector(IVRFProxy.requestRandomWords.selector), abi.encode(0));
        vm.expectCall(MOCK_VRF_COORDINATOR, abi.encodeWithSelector(IVRFProxy.requestRandomWords.selector));

        // Take a guess.
        consumer.takeAGuess(number);

        // Get the new bet.
        (address guesser, uint256 guess,) = consumer.guesses(expectedRequestId);
        assertEq(guesser, address(this));
        assertEq(guess, number);
    }

    function testFulfillRandomWordsInvalidLength() public {
        uint256[] memory randomWords = new uint256[](2);
        randomWords[0] = 67;
        randomWords[1] = 68;

        // The game only allows a single random word.
        vm.prank(MOCK_VRF_COORDINATOR);
        vm.expectRevert(VRFConsumer.InvalidDataLength.selector);
        consumer.rawFulfillRandomWords(123, randomWords);
    }
}
