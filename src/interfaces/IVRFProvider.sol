// SPDX-License-IDentifier: UNLICENSED
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
        uint256 proxyRequestID;
        uint32 messageCallbackGasLimit;
    }

    /**
     * @dev Proxy spendings structure containins necessary values to track in order to implement autonomous allowance mechanism.
     * @dev This allowance system enables proxies to have certain allowance on a daily basis, each day allowance is reset to a predetermined value.
     * @param day is an identifier of a day in which last request was made, it is set in order to track spendings in a certain day,
     * and reset spendings to zero once new day approaches.
     * @param spendings is a total of spendings made in a single day by a proxy (this variable will show value for the last day
     * in which proxy was used or just zero if it was never used).
     */
    struct ProxySpendings {
        uint256 day;
        uint256 spendings;
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
    error InvalidProxyAddress();
    /**
     * @dev Reverting when proxy crosses its spending limit for the day.
     * @param sourceBlockchainID is the id of a blockchain where proxy is deployed.
     * @param originSenderAddress is a proxy address.
     * @param day is an identifier of a day on which the event has occured.
     */
    error AllowanceLimitReached(bytes32 sourceBlockchainID, address originSenderAddress, uint256 day);

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
