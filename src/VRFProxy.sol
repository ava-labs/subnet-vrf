// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFConsumerRegistry} from "./interfaces/IVRFConsumerRegistry.sol";
import {IVRFProxy} from "./interfaces/IVRFProxy.sol";
import {VRFRequestInfo, VRFResponseInfo} from "./interfaces/IVRF.sol";
import {GasUtils} from "./libraries/GasUtils.sol";
import {
    TeleporterMessageInput, TeleporterFeeInfo
} from "@teleporter/contracts/src/Teleporter/ITeleporterMessenger.sol";
import {TeleporterOwnerUpgradeable} from "@teleporter/contracts/src/Teleporter/upgrades/TeleporterOwnerUpgradeable.sol";
import {VRFV2WrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";

contract VRFProxy is IVRFProxy, TeleporterOwnerUpgradeable {
    /// @inheritdoc IVRFProxy
    IVRFConsumerRegistry public immutable vrfConsumerRegistry;
    /// @inheritdoc IVRFProxy
    bytes32 public immutable vrfProviderBlockchainID;
    /// @inheritdoc IVRFProxy
    address public immutable vrfProviderAddress;
    /// @inheritdoc IVRFProxy
    uint256 public requestNonce;
    /// @inheritdoc IVRFProxy
    mapping(uint256 requestID => address requester) public requesters;

    /// Chainlink Avalanche values
    uint16 public minimumConfirmations = 0;
    uint16 public constant MAXIMUM_CONFIRMATIONS = 200;
    uint32 public constant MAXIMUM_RANDOM_WORDS = 500;

    /// @inheritdoc IVRFProxy
    uint256 public constant VRF_REQUEST_REQUIRED_GAS = 500_000;

    constructor(
        address teleporterRegistryAddress_,
        address vrfConsumerRegistry_,
        bytes32 vrfProviderBlockchainID_,
        address vrfProviderAddress_
    ) TeleporterOwnerUpgradeable(teleporterRegistryAddress_, msg.sender) {
        if (vrfProviderAddress_ == address(0)) revert VRFProviderAddressIsZero();
        vrfProviderAddress = vrfProviderAddress_;
        if (vrfConsumerRegistry_ == address(0)) revert VRFConsumerRegistryAddressIsZero();
        vrfConsumerRegistry = IVRFConsumerRegistry(vrfConsumerRegistry_);
        if (vrfProviderBlockchainID_ == bytes32(0)) revert VRFProviderBlockchainIDIsZero();
        vrfProviderBlockchainID = vrfProviderBlockchainID_;
    }

    /// @inheritdoc IVRFProxy
    function setMinimumConfirmations(uint16 minimumConfirmations_) external onlyOwner {
        if (minimumConfirmations_ > MAXIMUM_CONFIRMATIONS) revert InvalidValue();
        minimumConfirmations = minimumConfirmations_;
    }

    /// @inheritdoc IVRFProxy
    function requestRandomWords(uint16 minimumRequestConfirmations, uint32 callbackGasLimit, uint32 numWords)
        external
        returns (uint256)
    {
        if (!vrfConsumerRegistry.isApprovedConsumer(msg.sender)) revert CallerIsNotAnApprovedConsumer();
        if (minimumRequestConfirmations < minimumConfirmations || minimumRequestConfirmations > MAXIMUM_CONFIRMATIONS) {
            revert MinimumRequestConfirmationsIsOutOfBounds();
        }
        if (numWords > MAXIMUM_RANDOM_WORDS) revert NumberOfRequestedWordsIsOverTheLimit();
        // Assign the next nonce to be used at the request ID.
        uint256 nonce = ++requestNonce;
        VRFRequestInfo memory requestInfo = VRFRequestInfo({
            requestID: nonce,
            minimumRequestConfirmations: minimumRequestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: numWords
        });

        // Store the address requesting the random value to be called
        // when the random value is fulfilled via receival of a Teleporter
        // message.
        requesters[nonce] = msg.sender;

        // Submit the VRF request to the partner VRFProvider via Teleporter message.
        _getTeleporterMessenger().sendCrossChainMessage(
            TeleporterMessageInput({
                destinationBlockchainID: vrfProviderBlockchainID,
                destinationAddress: vrfProviderAddress,
                feeInfo: TeleporterFeeInfo({feeTokenAddress: address(0), amount: 0}),
                requiredGasLimit: VRF_REQUEST_REQUIRED_GAS,
                allowedRelayerAddresses: new address[](0),
                message: abi.encode(requestInfo, msg.sender)
            })
        );

        emit RandomWordsRequested({
            requestID: nonce,
            requester: msg.sender,
            minimumRequestConfirmations: minimumRequestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: numWords
        });

        return nonce;
    }

    /**
     * @dev Called when a Teleporter message is delivered to this VRFProxyContract. Verifies the sender of the message
     * and then processes it by passing the random values back to their original requester.
     * @param sourceBlockchainID - The blockchain ID where the message originated. The only allowed sender is
     * the vrfProviderBlockchainID.
     * @param originSenderAddress - The address of the message sender on the source blockchain. The only allowed sender
     * is the vrfProviderAddress.
     * @param message - The raw Teleporter message payload. Expected to be an ABI encoded VRFResponseInfo instance.
     */
    function _receiveTeleporterMessage(bytes32 sourceBlockchainID, address originSenderAddress, bytes memory message)
        internal
        override
    {
        // Verify the sender.
        if (sourceBlockchainID != vrfProviderBlockchainID) revert InvalidSourceBlockchainID();
        if (originSenderAddress != vrfProviderAddress) revert CallerNotVRFProvider();

        // Decode the response.
        VRFResponseInfo memory response = abi.decode(message, (VRFResponseInfo));
        // gas opt
        uint256 requestID = response.requestID;

        // Look up the requester.
        address requester = requesters[requestID];
        if (requester == address(0)) revert InvalidRequestID();

        // Clear the requesting address since the request is now fulfilled.
        delete requesters[requestID];

        // Pass the result to the destination with the exact gas limit.
        bytes memory resp =
            abi.encodeCall(VRFV2WrapperConsumerBase.rawFulfillRandomWords, (requestID, response.randomWords));

        // Call with explicitly the amount of callback gas requested.
        // Note that _callWithExactGas will revert if we do not have sufficient gas
        // to give the callee their requested amount.
        bool success = GasUtils._callWithExactGas(response.callbackGasLimit, requester, resp);
        emit RandomWordsFulfilled(requestID, success);
    }
}
