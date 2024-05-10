// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRF} from "./IVRF.sol";

interface IVRFProvider is IVRF {

    /**
     * Errors
     */
    error InsufficientBalance();
    error ConsumerNotApprovedBySelectedStakeholder();
    error CallerIsNotAnApprovedProxy();
    error VRFProxyRegistryAddressIsZero();
    error InvalidProxyRequestID();
    error InvalidChainlinkVRFRequestID();

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

    /**
     * @dev Emitted when $LINK is deposited to the contract.
     */
    event Deposit(uint256 amount);

    /**
     * @dev Emitted when $LINK is withdrawn from the contract.
     */
    event Withdraw(uint256 amount);

    /**
     * @dev Emitted when $LINK payment has been made with purpose of a VRF request creation.
     */
    event Payment(address indexed proxyAddress, uint256 indexed proxyRequestID, uint256 total);

    /**
     * @dev Emitted when a message is received from the partner VRFProxy requesting random values.
     * @param proxyRequestID - The request ID specified in the message from the VRFProxy. Separate from the
     * Chainlink VRF request ID assigned when the request is submitted to the Chainlink VRF coordinator.
     * @param chainlinkVRFRequestID - The request ID assigned by the Chainlink VRF coordinator for
     * the random value request. Separate from the proxy request ID.
     * @param numWords - The number of random uint256 words requested.
     */
    event VRFRequestReceived(
        bytes32 blockchainID,
        address sourceSender,
        uint256 indexed proxyRequestID,
        uint256 indexed chainlinkVRFRequestID,
        uint32 numWords
    );

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
