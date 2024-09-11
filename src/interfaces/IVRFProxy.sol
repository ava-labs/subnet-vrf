// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {ITeleporterReceiver} from "@teleporter/contracts/src/Teleporter/ITeleporterReceiver.sol";
import {IVRFConsumerRegistry} from "./IVRFConsumerRegistry.sol";

interface IVRFProxy is ITeleporterReceiver {
    /**
     * @dev Emmited when a request for random words is made.
     */
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
     */
    event RandomWordsFulfilled(uint256 indexed requestID);

    /**
     * Errors
     */
    error VRFProviderAddressIsZero();
    error VRFConsumerRegistryAddressIsZero();
    error VRFProviderBlockchainIDIsZero();
    error CallerIsNotAnApprovedConsumer();
    error InvalidSourceBlockchainID();
    error CallerNotVRFProvider();
    error InvalidRequestID();
    error ConsumerCallFailed();

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
    function requestRandomWords(uint16 minimumRequestConfirmations, uint32 callbackGasLimit, uint32 numWords)
        external
        returns (uint256);

    /**
     * @dev The contract storing wallet approval statuses, defining the approved consumers.
     */
    function vrfConsumerRegistry() external view returns (IVRFConsumerRegistry);

    /**
     * @dev The blockchain ID of the partner blockchain where the VRFProvider contract is deployed.
     */
    function vrfProviderBlockchainID() external view returns (bytes32);

    /**
     * @dev The contract adddress of the VRFProvider to be used on the partner blockchain.
     */
    function vrfProviderAddress() external view returns (address);

    /**
     * @dev The number of requests for random values that have been made to this VRFPRoxy. Used as unique request IDs.
     */
    function requestNonce() external view returns (uint256);

    /**
     * @dev The address that request the random values for each request ID.
     */
    function requesters(uint256 requestID) external view returns (address);

    /**
     * @dev The estimated amount of gas used by the VRFProvider on the partner chain to request random values from the
     * Chainlink VRF coordinator. This is the required gas limit for the Teleporter message sent to request the values.
     */
    // solhint-disable-next-line
    function VRF_REQUEST_REQUIRED_GAS() external pure returns (uint256);
}
