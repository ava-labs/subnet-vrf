// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.25;

import {ITeleporterReceiver} from "@teleporter/ITeleporterReceiver.sol";
import {IVRFProxyRegistry} from "./IVRFProxyRegistry.sol";

interface IVRFProvider is ITeleporterReceiver {
    /**
     * @dev  The components of VRFRequestInfo that need to be persisted when requesting
     * random values from the Chainlink VRF coordinator. These values will be sent
     * back to the partner VRFCoorindator as part of the message to fulfill
     * the request.
     * @param sourceBlockchainID is an id of the origin network from which the request arrived.
     * @param originSenderAddress is an address of a proxy contract which forwarded consumer's request to the Teleporter on the network of origin.
     * @param proxyRequestID is an id of a request local to the proxy through which it was made.
     * @param messageCallbackGasLimit is a total value of gas limit being set for an execution of a request callback.
     */
    struct InternalRequestInfo {
        bytes32 sourceBlockchainID;
        address originSenderAddress;
        uint32 messageCallbackGasLimit;
        uint256 proxyRequestID;
    }

    /**
     * @dev Proxy spendings structure contains necessary values to track in order to implement autonomous allowance mechanism.
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
     * @param funder is a newly added funder address.
     */
    event FunderAdded(address indexed funder);

    /**
     * @dev Emitted when an authorized funder is removed.
     * @param funder is a removed funder address.
     */
    event FunderRemoved(address indexed funder);

    /**
     * @dev Emitted when $LINK is deposited to the contract.
     * @param amount is amount of $LINK deposited.
     */
    event Deposit(address indexed authorizedFunder, uint256 amount);

    /**
     * @dev Emitted when $LINK is withdrawn from the contract.
     * @param amount is amount of $LINK withdrawn.
     */
    event Withdraw(uint256 amount);

    /**
     * @dev Emitted when $LINK payment has been made with purpose of a VRF request creation.
     * @param proxyAddress is an address of a proxy through which the request was made on the subnet of origin
     * @param proxyRequestID is an id of a request that was made through the proxy on the subnet of origin
     * this parameter helps us retrieve request data through the proxy using a specific id, proxy request ids are local.
     * @param total is a request price total.
     */
    event Payment(
        bytes32 indexed sourceBlockchainID, address indexed proxyAddress, uint256 indexed proxyRequestID, uint256 total
    );

    /**
     * @dev Emitted when a message is received from the partner VRFProxy requesting random values.
     * @param blockchainID - an id of the origin network from which the request arrived.
     * @param sourceSender - an address of a proxy contract which forwarded consumer's request to the Teleporter on the network of origin.
     * @param proxyRequestID - The request ID specified in the message from the VRFProxy. Separate from the
     * Chainlink VRF request ID assigned when the request is submitted to the Chainlink VRF coordinator.
     * @param chainlinkVRFRequestID - The request ID assigned by the Chainlink VRF coordinator for
     * the random value request. Separate from the proxy request ID.
     * @param numWords - The number of random uint256 words requested.
     * @param consumer - an address of a wallet which made a VRF request through proxy on the network of origin.
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
     * @dev Emitted once a request for random words is cached - this happens when the Teleporter is paused.
     * @dev Cached responses can be bridged only manually.
     * @param chainlinkVRFRequestID is an id of a request for which the received response was cached but not bridged.
     */
    event ResponseCached(uint256 indexed chainlinkVRFRequestID);

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
    error RequestNotCached();

    /**
     * @dev Function to add authorized funders
     * @param funders is an array of funder addresses to be added.
     */
    function addFunders(address[] calldata funders) external;

    /**
     * @dev Function to remove authorized funders
     * @param funders is an array of funder addresses to be removed.
     */
    function removeFunders(address[] calldata funders) external;

    /**
     * @dev Enables stakeholders to deposit $LINK.
     * @param amount is amount of $LINK to be deposited.
     */
    function deposit(uint256 amount) external;

    /**
     * @dev Enables owner to withdraw the $LINK.
     * @param amount is amount of $LINK to be withdrawn, needs to be lesser than or equal to contract balance.
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
     * @dev Mapping which tracks the authorized funders.
     * @param account is an account to check status of (if it is an authorized funder or not).
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
