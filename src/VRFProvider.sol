// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFProvider} from "./interfaces/IVRFProvider.sol";
import {VRFV2WrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import {
    TeleporterMessageInput, TeleporterFeeInfo
} from "@teleporter/contracts/src/Teleporter/ITeleporterMessenger.sol";
import {TeleporterOwnerUpgradeable} from "@teleporter/contracts/src/Teleporter/upgrades/TeleporterOwnerUpgradeable.sol";

contract VRFProvider is IVRFProvider, VRFV2WrapperConsumerBase, TeleporterOwnerUpgradeable {
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
     * @dev Tracks the request information by the Chainlink VRF request ID.
     */
    mapping(uint256 chainlinkVRFRequestID => InternalRequestInfo requestInfo) internal _requests;

    /**
     * @dev Gas limits for receiving random words from the Chainlink VRF coordinator, and sending
     * them in a Teleporter message to the partner Teleporter VRF coordinator contract.
     */
    uint32 public constant TELEPORTER_CALLBACK_GAS_LIMIT_BASE = 300_000;
    uint32 public constant TELEPORTER_CALLBACK_GAS_LIMIT_PER_WORD = 5_000;
    uint32 public constant TELEPORTER_RECEIVE_MESSAGE_GAS_OVERHEAD = 300_000;

    constructor(
        address teleporterRegistryAddress_,
        address chainlinkVRFWrapper_,
        address link_
    )
        TeleporterOwnerUpgradeable(teleporterRegistryAddress_, msg.sender)
        VRFV2WrapperConsumerBase(link_, chainlinkVRFWrapper_)
    {}

    /**
     * @dev Fulfills the VRF request identified by the given request ID with the randomWords provided. Called from
     * VRFConsumerBaseV2, where authentication occurs requiring that the random words must be provided by the
     * VRFCoordinator contract, which verifies the randomness proof.
     *
     * When random value requests are fulfilled, their corresponding VRFProxy request is looked up,
     * and the resulting random values with relevant information are sent back to the VRFProxy via Teleporter message.
     */
    // Need to provide an implementation of fulfillRandomWords (without a leading "_") for VRFConsumerBaseV2
    // solhint-disable-next-line
    function fulfillRandomWords(uint256 chainlinkVRFRequestID, uint256[] memory randomWords)
        internal
        override
    {
        // Look up the corresponding VRFProxy request info for this chainlinkVRFRequestID to know
        // the correct data to include in the response.
        InternalRequestInfo memory requestInfo = _requests[chainlinkVRFRequestID];
        require(requestInfo.proxyRequestID != 0, "VRFProvider: invalid Chainlink VRF request ID");

        emit VRFRequestFulfilled(requestInfo.proxyRequestID, chainlinkVRFRequestID, uint32(randomWords.length));

        // Send the result back to the VRFProxy via Teleporter message.
        VRFResponseInfo memory response = VRFResponseInfo({
            requestID: requestInfo.proxyRequestID,
            randomWords: randomWords,
            callbackGasLimit: requestInfo.messageCallbackGasLimit
        });
        _getTeleporterMessenger().sendCrossChainMessage(
            TeleporterMessageInput({
                destinationBlockchainID: requestInfo.sourceBlockchainID,
                destinationAddress: requestInfo.originSenderAddress,
                feeInfo: TeleporterFeeInfo({feeTokenAddress: address(0), amount: 0}),
                requiredGasLimit: requestInfo.messageCallbackGasLimit + TELEPORTER_RECEIVE_MESSAGE_GAS_OVERHEAD,
                allowedRelayerAddresses: new address[](0),
                message: abi.encode(response)
            })
        );
    }

    /**
     * @dev Called when a Teleporter message is delivered to this VRFProvider. Verifies the sender of the message
     * is the partner VRFProxy, and then passes the random value request on the Chainlink VRF Coordinator.
     * @param sourceBlockchainID - The blockchain ID where the message originated. The only allowed sender is
     * the vrfProxyBlockchainID.
     * @param originSenderAddress - The address of the message sender on the source blockchain. The only allowed sender
     * is the vrfProxyAddress.
     * @param message - The raw Teleporter message payload. Expected to be an ABI encoded VRFRequestInfo instance.
     */
    function _receiveTeleporterMessage(bytes32 sourceBlockchainID, address originSenderAddress, bytes memory message)
        internal
        override
    {
        // Decode the request.
        VRFRequestInfo memory request = abi.decode(message, (VRFRequestInfo));
        require(request.requestID != 0, "VRFProvider: invalid proxy request ID");

        // Pass the request on the Chainlink VRF coordinator
        uint256 chainlinkVRFRequestID = requestRandomness(
            request.minimumRequestConfirmations,
            TELEPORTER_CALLBACK_GAS_LIMIT_BASE + (TELEPORTER_CALLBACK_GAS_LIMIT_PER_WORD * request.numWords),
            request.numWords
        );

        emit VRFRequestReceived(sourceBlockchainID, originSenderAddress, request.requestID, chainlinkVRFRequestID, request.numWords);

        _requests[chainlinkVRFRequestID] =
            InternalRequestInfo({
                sourceBlockchainID: sourceBlockchainID,
                originSenderAddress: originSenderAddress,
                proxyRequestID: request.requestID,
                messageCallbackGasLimit: request.callbackGasLimit
            });
    }
}
