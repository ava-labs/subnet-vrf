// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IVRFProxy {
    event RandomWordsRequested(
        uint256 indexed requestID,
        address indexed requester,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    );

    /**
     * @dev Emitted when a request for random words is fulfilled.
     * @param requestID - A unique ID for the request. This is assigned by the VRFProxy, and separate from the request
     * ID assigned by the Chainlink VRF Coordinator on the partner chain.
     * @param success - Whether or not the call to the requester's fulfillRandomWords fundction succeeded. The requesters
     * are responsible for the correctness of their own implementation. Success cannot be ensured by the VRFProxy.
     */
    event RandomWordsFulfilled(uint256 indexed requestID, bool success);
}
