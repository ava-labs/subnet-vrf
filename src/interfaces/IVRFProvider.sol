// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ITeleporterReceiver} from "@teleporter/contracts/src/Teleporter/ITeleporterReceiver.sol";
import {IVRFProxyRegistry} from "./IVRFProxyRegistry.sol";

interface IVRFProvider is ITeleporterReceiver {
    /**
     * @dev  The components of VRFRequestInfo that need to be persisted when requesting
     * random values from the Chainlink VRF coordinator. These values will be sent
     * back to the partner VRFCoorindator as part of the message to fulfill
     * the request.
     */
    struct InternalRequestInfo {
        bytes32 sourceBlockchainID;
        address originSenderAddress;
        uint32 messageCallbackGasLimit;
        uint256 proxyRequestID;
    }

    /**
     * @dev Emitted when a new authorized funder is added.
     */
    event FunderAdded(address indexed funder);

    /**
     * @dev Emitted when an authorized funder is removed.
     */
    event FunderRemoved(address indexed funder);

    /**
     * @dev Emitted when $LINK is deposited to the contract.
     */
    event Deposit(address indexed authorizedFunder, uint256 amount);

    /**
     * @dev Emitted when $LINK is withdrawn from the contract.
     */
    event Withdraw(uint256 amount);

    /**
     * @dev Emitted when $LINK payment has been made with purpose of a VRF request creation.
     */
    event Payment(
        bytes32 indexed sourceBlockchainID, address indexed proxyAddress, uint256 indexed proxyRequestID, uint256 total
    );

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
        uint32 numWords,
        address indexed consumer
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

    /**
     * Errors
     */
    error NotAnAuthorizedFunder();
    error InsufficientBalance();
    error InvalidCallerOrSourceChainID();
    error InvalidProxyRequestID();
    error InvalidChainlinkVRFRequestID();
    error VRFProxyRegistryAddressIsZero();

    /**
     * @dev Function to add authorized funders
     */
    function addFunders(address[] calldata funders) external;

    /**
     * @dev Function to remove authorized funders
     */
    function removeFunders(address[] calldata funders) external;

    /**
     * @dev Enables stakeholders to deposit $LINK
     */
    function deposit(uint256 amount) external;

    /**
     * @dev Enables external parties and service users to withdraw their $LINK
     */
    function withdraw(uint256 amount) external;

    /**
     * @dev Variable containing the $LINK balance, deposited by the official authorities.
     */
    function balance() external view returns (uint256);

    /**
     * @dev Variable containing the VRF Proxy Registry, contract used for management of proxies.
     */
    function vrfProxyRegistry() external view returns (IVRFProxyRegistry);

    /**
     * @dev Mapping which tracks the authorized funders
     */
    function authorizedFunders(address account) external view returns (bool);

    /**
     * @dev Gas limits for receiving random words from the Chainlink VRF coordinator, and sending
     * them in a Teleporter message to the partner Teleporter VRF coordinator contract.
     */
    /* solhint-disable */
    function TELEPORTER_CALLBACK_GAS_LIMIT_BASE() external pure returns (uint32);
    function TELEPORTER_CALLBACK_GAS_LIMIT_PER_WORD() external pure returns (uint32);
    function TELEPORTER_RECEIVE_MESSAGE_GAS_OVERHEAD() external pure returns (uint32);
    /* solhint-enable */
}
