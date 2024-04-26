// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRF} from "./IVRF.sol";

interface IVRFProvider is IVRF {
    error InsufficientBalance();
    error ConsumerNotApprovedBySelectedStakeholder();

    /**
     * @dev  The components of VRFRequestInfo that need to be persisted when requesting
     * random values from the Chainlink VRF coordinator. These values will be sent
     * back to the partner VRFCoorindator as part of the message to fulfill
     * the request.
     */
    struct InternalRequestInfo {
        bytes32 sourceBlockchainID;
        address originSenderAddress;
        uint256 proxyRequestID;
        uint32 messageCallbackGasLimit;
    }

    event LinkDeposit(address indexed stakeholder, uint256 amount);
    event LinkWithdraw(address indexed stakeholder, uint256 amount);
    event ConsumerAdded(address indexed consumer);
    event ConsumerRemoved(address indexed consumer);

    event Payment(address indexed stakeholder, address indexed consumer, uint256 total);
    /**
     * @dev Emitted when a message is received from the partner VRFProxy requesting random values.
     * @param proxyRequestID - The request ID specified in the message from the VRFProxy. Separate from the
     * Chainlink VRF request ID assigned when the request is submitted to the Chainlink VRF coordinator.
     * @param chainlinkVRFRequestID - The request ID assigned by the Chainlink VRF coordinator for
     * the random value request. Separate from the proxy request ID.
     * @param numWords - The number of random uint256 words requested.
     */
    event VRFRequestReceived(bytes32 blockchainId, address sourceSender, uint256 indexed proxyRequestID, uint256 indexed chainlinkVRFRequestID, uint32 numWords);

    /**
     * @dev Emitted when a VRF request is fulfilled by the Chainlink VRF Coordinator, and the random
     * values are sent back the partner VRFProxy via Teleporter message.
     * @param proxyRequestID - The request ID specified in the message from the VRFProxy. Separate from the
     * Chainlink VRF request ID assigned when the request is submitted to the Chainlink VRF coordinator.
     * @param chainlinkVRFRequestID - The request ID assigned by the Chainlink VRF coordinator for
     * the random value request. Separate from the proxy request ID.
     * @param numWords - The number of random uint256 words.
     */
    event VRFRequestFulfilled(uint256 indexed proxyRequestID, uint256 indexed chainlinkVRFRequestID, uint32 numWords);
}
