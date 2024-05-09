// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFProvider} from "./interfaces/IVRFProvider.sol";
import {IVRFProxyRegistry} from "./interfaces/IVRFProxyRegistry.sol";
import {VRFV2WrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import {
    TeleporterMessageInput, TeleporterFeeInfo
} from "@teleporter/contracts/src/Teleporter/ITeleporterMessenger.sol";
import {TeleporterOwnerUpgradeable} from "@teleporter/contracts/src/Teleporter/upgrades/TeleporterOwnerUpgradeable.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract VRFProvider is IVRFProvider, VRFV2WrapperConsumerBase, TeleporterOwnerUpgradeable {

    /**
     * @dev Variable containing the $LINK balance, deposited by the official authorities.
     */
    uint256 public balance;

    /**
     * @dev Variable containing the VRF Proxy Registry, contract used for management of proxies.
     */
    IVRFProxyRegistry public vrfProxyRegistry;

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
        address vrfProxyRegistry_,
        address chainlinkVRFWrapper_,
        address link_
    )
        TeleporterOwnerUpgradeable(teleporterRegistryAddress_, msg.sender)
        VRFV2WrapperConsumerBase(link_, chainlinkVRFWrapper_)
    {
        if (vrfProxyRegistry_ == address(0)) revert VRFProxyRegistryAddressIsZero();
        vrfProxyRegistry = IVRFProxyRegistry(vrfProxyRegistry_);
    }

    /**
     * @dev Enables stakeholders to deposit $LINK
     */
    function deposit(uint256 amount) external onlyOwner {
        LINK.transferFrom(msg.sender, address(this), amount);
        unchecked {
            balance += amount;
        }
        emit Deposit(amount);
    }

    /**
     * @dev Enables external parties and service users to withdraw their $LINK
     */
    function withdraw(uint256 amount) external onlyOwner {
        if (balance >= amount) revert InsufficientBalance();
        unchecked {
            balance -= amount;
        }
        LINK.transfer(msg.sender, amount);
        emit Withdraw(amount);
    }

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
        if (requestInfo.proxyRequestID == 0) revert InvalidChainlinkVRFRequestID();

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
        if (!vrfProxyRegistry.isValid(sourceBlockchainID, originSenderAddress)) revert CallerIsNotAnApprovedProxy();

        // Decode the request.
        (VRFRequestInfo memory request) = abi.decode(message, (VRFRequestInfo));
        // gas opt
        uint256 proxyRequestID = request.requestID;
        uint32 numWords = request.numWords;
        if (proxyRequestID == 0) revert InvalidProxyRequestID();

        uint32 total = TELEPORTER_CALLBACK_GAS_LIMIT_BASE + (TELEPORTER_CALLBACK_GAS_LIMIT_PER_WORD * numWords);

        // Ensure that stakeholder has enough balance
        if (total > balance) revert InsufficientBalance();
        unchecked {
             balance -= total;
        }

        emit Payment(originSenderAddress, proxyRequestID, total);

        // Pass the request on the Chainlink VRF coordinator
        uint256 chainlinkVRFRequestID = requestRandomness(
            total,
            request.minimumRequestConfirmations,
            numWords
        );

        emit VRFRequestReceived(sourceBlockchainID, originSenderAddress, proxyRequestID, chainlinkVRFRequestID, numWords);

        _requests[chainlinkVRFRequestID] =
            InternalRequestInfo({
                sourceBlockchainID: sourceBlockchainID,
                originSenderAddress: originSenderAddress,
                proxyRequestID: proxyRequestID,
                messageCallbackGasLimit: request.callbackGasLimit
            });
    }
}
