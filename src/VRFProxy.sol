// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFConsumerRegistry} from "./interfaces/IVRFConsumerRegistry.sol";
import {IVRFProxy} from "./interfaces/IVRFProxy.sol";
import {GasUtils} from "./libraries/GasUtils.sol";
import {
    TeleporterMessageInput, TeleporterFeeInfo
} from "@teleporter/contracts/src/Teleporter/ITeleporterMessenger.sol";
import {TeleporterOwnerUpgradeable} from "@teleporter/contracts/src/Teleporter/upgrades/TeleporterOwnerUpgradeable.sol";
import {VRFV2WrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";

contract VRFProxy is IVRFProxy, TeleporterOwnerUpgradeable {
    /**
     * @dev The estimated amount of gas used by the VRFProvider on the partner chain to request random values from the
     * Chainlink VRF coordinator. This is the required gas limit for the Teleporter message sent to request the values.
     */
    uint256 public constant VRF_REQUEST_REQUIRED_GAS = 500_000;

    /**
     * @dev The contract storing wallet statudrd, defining the approved consumers.
     */
    IVRFConsumerRegistry public immutable vrfConsumerRegistry;

    /**
     * @dev The blockchain ID of the partner blockchain where the VRFProvider contract is deployed.
     */
    bytes32 public immutable vrfProviderBlockchainID;

    /**
     * @dev The contract adddress of the VRFProvider to be used on the partner blockchain.
     */
    address public immutable vrfProviderAddress;

    /**
     * @dev The number of requests for random values that have been made to this VRFPRoxy. Used as unique request IDs.
     */
    uint256 public requestNonce;

    /**
     * @dev The address that request the random values for each request ID.
     */
    mapping(uint256 requestID => address requester) public requesters;

    constructor(address teleporterRegistryAddress_, address vrfConsumerRegistry_, bytes32 vrfProviderBlockchainID_, address vrfProviderAddress_)
        TeleporterOwnerUpgradeable(teleporterRegistryAddress_, msg.sender)
    {
        if (vrfProviderAddress_ == address(0)) revert VRFProviderAddressIsZero();
        vrfProviderAddress = vrfProviderAddress_;
        if (vrfConsumerRegistry_ == address(0)) revert VRFConsumerRegistryAddressIsZero();
        vrfConsumerRegistry = IVRFConsumerRegistry(vrfConsumerRegistry_);
        if (vrfProviderBlockchainID_ == bytes32(0)) revert VRFProviderBlockchainIDIsZero();
        vrfProviderBlockchainID = vrfProviderBlockchainID_;
    }

    /**
     * @notice Request a set of random words.
     * The request is passed on to the partner chain where the VRFProvider is deployed via Teleporter message.
     * See https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol#L13
     * for further documentation of how each value is used within Chainlink VRF reuests.
     * @param minimumRequestConfirmations - How many blocks you'd like the VRF service on the partner chain to wait prior
     * to fulfilling the request once the VRF provider submits the request on the partner chain.
     * @param callbackGasLimit - How much gas needs to be provided to the fulfillRandomWords call to complete this randomness request.
     * @param numWords - The number of uint256 values requested.
     * @return requestID - A unique identifier of the request. Can be used to match a request to a reponse in fulfillRandomWords. This
     * request ID is separate from any VRF request ID assigned on the partner chain by the VRFProdiver.
     */
    function requestRandomWords(
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256) {
        if (!vrfConsumerRegistry.isValid(msg.sender)) revert CallerIsNotAnApprovedConsumer();
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
            abi.encodeWithSelector(VRFV2WrapperConsumerBase.rawFulfillRandomWords.selector, requestID, response.randomWords);

        // Call with explicitly the amount of callback gas requested.
        // Note that _callWithExactGas will revert if we do not have sufficient gas
        // to give the callee their requested amount.
        bool success = GasUtils._callWithExactGas(response.callbackGasLimit, requester, resp);
        emit RandomWordsFulfilled(requestID, success);
    }

}
