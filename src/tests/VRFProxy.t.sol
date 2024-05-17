// SPDX-License-Identifier: Ecosystem
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {VRFProxy} from "../VRFProxy.sol";
import {IVRF} from "../interfaces/IVRF.sol";
import {VRFConsumerRegistry} from "../VRFConsumerRegistry.sol";
import {TeleporterRegistry} from "@teleporter/contracts/src/Teleporter/upgrades/TeleporterRegistry.sol";
import {
    ITeleporterMessenger,
    TeleporterMessageInput,
    TeleporterFeeInfo
} from "@teleporter/contracts/src/Teleporter/ITeleporterMessenger.sol";
import {VRFConsumer} from "../mocks/VRFConsumer.sol";
import {Strings} from "@openzeppelin/contracts@4.8.1/utils/Strings.sol";

contract VRFProxyTest is IVRF, Test {
    address public immutable ADMIN;
    address[] public MANAGERS;
    address[] public consumers;

    /**
     * @dev Role which is has permission to add new consumers (but not to remove existing ones)
     */
    bytes32 public constant CONSUMER_MANAGER = keccak256("CONSUMER_MANAGER");

    address public constant MOCK_TELEPOTER_MESSENGER_ADDRESS = address(0x1111);
    uint256 public constant MOCK_LATEST_TELEPORTER_VERSION = 1;
    address public constant MOCK_TELEPORTER_REGISTRY_ADDRESS = address(0x2222);
    bytes32 public constant MOCK_VRF_PROVIDER_BLOCKCHAIN_ID =
        bytes32(hex"1234567812345678123456781234567812345678123456781234567812345678");
    address public constant MOCK_VRF_PROVIDER_ADDRESS = address(0x3333);
    address public constant MOCK_CONSUMER = address(0x4444);

    VRFConsumerRegistry public vrfConsumerRegistry;
    VRFProxy public vrfProxy;

    address private constant mockConsumer = address(0x5555);
    address private constant nonOwnerAddress = address(0x6666);

    // Events emitted by VRFProxy
    event ConsumerAdded(address indexed consumer);
    event ConsumerRemoved(address indexed consumer);
    event RandomWordsRequested(
        uint256 indexed requestID,
        address indexed requester,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    );
    event RandomWordsFulfilled(uint256 indexed requestID, bool success);

    constructor() {
        ADMIN = msg.sender;
        MANAGERS = new address[](1);
        MANAGERS[0] = msg.sender;
        consumers = new address[](1);
    }

    function setUp() public virtual {
        vm.mockCall(
            MOCK_TELEPORTER_REGISTRY_ADDRESS,
            abi.encodeWithSelector(TeleporterRegistry(MOCK_TELEPORTER_REGISTRY_ADDRESS).latestVersion.selector),
            abi.encode(MOCK_LATEST_TELEPORTER_VERSION)
        );
        vm.mockCall(
            MOCK_TELEPORTER_REGISTRY_ADDRESS,
            abi.encodeWithSelector(TeleporterRegistry(MOCK_TELEPORTER_REGISTRY_ADDRESS).getLatestTeleporter.selector),
            abi.encode(MOCK_TELEPOTER_MESSENGER_ADDRESS)
        );
        vm.mockCall(
            MOCK_TELEPORTER_REGISTRY_ADDRESS,
            abi.encodeWithSelector(
                TeleporterRegistry(MOCK_TELEPORTER_REGISTRY_ADDRESS).getVersionFromAddress.selector,
                MOCK_TELEPOTER_MESSENGER_ADDRESS
            ),
            abi.encode(MOCK_LATEST_TELEPORTER_VERSION)
        );
        vrfConsumerRegistry = new VRFConsumerRegistry(ADMIN, MANAGERS);
        vrfProxy = new VRFProxy(
            MOCK_TELEPORTER_REGISTRY_ADDRESS,
            address(vrfConsumerRegistry),
            MOCK_VRF_PROVIDER_BLOCKCHAIN_ID,
            MOCK_VRF_PROVIDER_ADDRESS
        );
    }

    function getAccessControlError(address account, bytes32 role) internal returns (string memory) {
        return string(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(account),
                " is missing role ",
                Strings.toHexString(uint256(role), 32)
            )
        );
    }

    function testAddConsumerSucess() public {
        _addConsumer(mockConsumer);
    }

    function testAddConsumerZeroAddress() public {
        vm.expectRevert("VRFProxy: zero consumer address");
        consumers[0] = address(0);
        vrfConsumerRegistry.addConsumers(consumers);
    }

    function testAddConsumerNotOwner() public {
        string memory err = 
            getAccessControlError(mockConsumer, CONSUMER_MANAGER);
        vm.expectRevert(
            err
        );
        vm.prank(nonOwnerAddress);
        consumers[0] = mockConsumer;
        vrfConsumerRegistry.addConsumers(consumers);
    }

    function addConsumerAlreadyAdded() public {
        _addConsumer(mockConsumer);
        vrfConsumerRegistry.addConsumers(consumers);
        assertTrue(vrfConsumerRegistry.isValid(mockConsumer));
    }

    function testRemoveConsumerSuccess() public {
        // Add a consumer.
        _addConsumer(mockConsumer);

        // Remove the consumer.
        vm.expectEmit(true, true, true, true, address(vrfProxy));
        emit ConsumerRemoved(mockConsumer);
        consumers[0] = mockConsumer;
        vrfConsumerRegistry.removeConsumers(consumers);
        assertFalse(vrfConsumerRegistry.isValid(mockConsumer));
    }

    function testRemoveConsumerNotFound() public {
        // Try to remove the consumer that was never added.
        vm.expectRevert("VRFProxy: invalid consumer");
        consumers[0] = mockConsumer;
        vrfConsumerRegistry.removeConsumers(consumers);
    }

    function testRemoveConsumerNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(nonOwnerAddress);
        consumers[0] = mockConsumer;
        vrfConsumerRegistry.removeConsumers(consumers);
    }

    function testRequestRandomWordsSuccess() public {
        // Add this contract as a consumer to be able to request values.
        _addConsumer(address(this));

        // Submit a request.
        uint256 expectedRequestID = vrfProxy.requestNonce() + 1;
        uint16 mockMinConfs = 1;
        uint32 mockCallbackGasLimit = 213_000;
        uint32 mockNumWords = 20;
        vm.mockCall(
            MOCK_TELEPOTER_MESSENGER_ADDRESS,
            abi.encodeWithSelector(ITeleporterMessenger.sendCrossChainMessage.selector),
            abi.encode(bytes32(0))
        );
        IVRF.VRFRequestInfo memory expectedRequest = IVRF.VRFRequestInfo({
            requestID: expectedRequestID,
            minimumRequestConfirmations: mockMinConfs,
            callbackGasLimit: mockCallbackGasLimit,
            numWords: mockNumWords
        });
        vm.expectCall(
            MOCK_TELEPOTER_MESSENGER_ADDRESS,
            abi.encodeWithSelector(
                ITeleporterMessenger.sendCrossChainMessage.selector,
                TeleporterMessageInput({
                    destinationBlockchainID: MOCK_VRF_PROVIDER_BLOCKCHAIN_ID,
                    destinationAddress: MOCK_VRF_PROVIDER_ADDRESS,
                    feeInfo: TeleporterFeeInfo({feeTokenAddress: address(0), amount: 0}),
                    requiredGasLimit: vrfProxy.VRF_REQUEST_REQUIRED_GAS(),
                    allowedRelayerAddresses: new address[](0),
                    message: abi.encode(expectedRequest)
                })
            )
        );
        vm.expectEmit(true, true, true, true, address(vrfProxy));
        emit RandomWordsRequested({
            requestID: expectedRequestID,
            requester: address(this),
            minimumRequestConfirmations: mockMinConfs,
            callbackGasLimit: mockCallbackGasLimit,
            numWords: mockNumWords
        });
        uint256 requestID = vrfProxy.requestRandomWords(mockMinConfs, mockCallbackGasLimit, mockNumWords);
        assertEq(requestID, expectedRequestID);
    }

    function testRequestRandomWordsNotAllowedConsumer() public {
        vm.expectRevert("VRFProxy: unauthorized consumer");
        vrfProxy.requestRandomWords(1, 200_000, 1);
    }

    function testReceiveTeleporterMessageSuccess() public {
        // Place a request from the expected consumer.
        uint32 callbackGasLimit = 100_000;
        uint256 requestID = _makeRandomWordsRequest(MOCK_CONSUMER, callbackGasLimit);

        // Format the message to be received.
        uint256[] memory mockValues = new uint256[](1);
        mockValues[0] = 321;
        VRFResponseInfo memory response =
            VRFResponseInfo({requestID: requestID, randomWords: mockValues, callbackGasLimit: callbackGasLimit});
        VRFConsumer consumer;
        vm.mockCall(
            MOCK_CONSUMER,
            abi.encodeWithSelector(consumer.rawFulfillRandomWords.selector, requestID, mockValues),
            new bytes(0)
        );
        vm.expectCall(
            MOCK_CONSUMER,
            0,
            callbackGasLimit,
            abi.encodeWithSelector(consumer.rawFulfillRandomWords.selector, requestID, mockValues)
        );
        vm.expectEmit(true, true, true, true, address(vrfProxy));
        emit RandomWordsFulfilled(requestID, true);
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage(
            MOCK_VRF_PROVIDER_BLOCKCHAIN_ID, MOCK_VRF_PROVIDER_ADDRESS, abi.encode(response)
        );
    }

    function testReceiveTeleporterMessageSuccessCallReverts() public {
        // Place a request from the expected consumer.
        uint32 callbackGasLimit = 100_000;
        uint256 requestID = _makeRandomWordsRequest(MOCK_CONSUMER, callbackGasLimit);

        // Format the message to be received.
        uint256[] memory mockValues = new uint256[](1);
        mockValues[0] = 321;
        VRFResponseInfo memory response =
            VRFResponseInfo({requestID: requestID, randomWords: mockValues, callbackGasLimit: callbackGasLimit});

        // Mock the consumer reverting in the call to rawFulfillRandomWords
        VRFConsumer consumer;
        vm.mockCall(MOCK_CONSUMER, abi.encodeWithSelector(consumer.rawFulfillRandomWords.selector), new bytes(0));
        vm.mockCallRevert(
            MOCK_CONSUMER,
            abi.encodeWithSelector(consumer.rawFulfillRandomWords.selector, requestID, mockValues),
            new bytes(0)
        );
        vm.expectCall(
            MOCK_CONSUMER,
            0,
            callbackGasLimit,
            abi.encodeWithSelector(consumer.rawFulfillRandomWords.selector, requestID, mockValues)
        );
        vm.expectEmit(true, true, true, true, address(vrfProxy));
        emit RandomWordsFulfilled(requestID, false);
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage(
            MOCK_VRF_PROVIDER_BLOCKCHAIN_ID, MOCK_VRF_PROVIDER_ADDRESS, abi.encode(response)
        );
    }

    function testReceiveTeleporterMessageInvalidBlockchainID() public {
        bytes32 otherBlockchainID = bytes32(hex"deaddeaddeaddeaddeaddeaddeaddeaddeaddeaddeaddeaddeaddeaddeaddead");
        vm.expectRevert("VRFProxy: invalid source blockchain ID");
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage(otherBlockchainID, MOCK_VRF_PROVIDER_ADDRESS, new bytes(0));
    }

    function testReceiveTeleporterMessageInvalidAddress() public {
        address otherAddress = address(0xbeef);
        vm.expectRevert("VRFProxy: invalid origin sender address");
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage(MOCK_VRF_PROVIDER_BLOCKCHAIN_ID, otherAddress, new bytes(0));
    }

    function testReceiveTeleporterMessageInvalidRequester() public {
        // Receive a message for a request ID that is not associated with any request.
        VRFResponseInfo memory response =
            VRFResponseInfo({requestID: 42, randomWords: new uint256[](1), callbackGasLimit: 10_000});

        vm.expectRevert("VRFProxy: invalid requester");
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage(
            MOCK_VRF_PROVIDER_BLOCKCHAIN_ID, MOCK_VRF_PROVIDER_ADDRESS, abi.encode(response)
        );
    }

    function testReceiveTeleporterMessageInsufficientGasForCheck() public {
        // Place a request from the expected consumer.
        uint32 callbackGasLimit = 100_000;
        uint256 requestID = _makeRandomWordsRequest(MOCK_CONSUMER, callbackGasLimit);

        // Format the response.
        VRFResponseInfo memory response =
            VRFResponseInfo({requestID: requestID, randomWords: new uint256[](1), callbackGasLimit: callbackGasLimit});

        // Expect it to revert if the call to receiveTeleporterMessage doesn't have sufficient gas for GAS_FOR_CALL_EXACT_CHECK.
        // 15,000 is just enough gas to reach the _callWithExactGas call with less than 5,000 gas remaining.
        uint32 gasInsufficientForCheck = 15_000;
        VRFConsumer consumer;
        vm.mockCall(
            MOCK_CONSUMER,
            abi.encodeWithSelector(consumer.rawFulfillRandomWords.selector, requestID, new uint256[](1)),
            new bytes(0)
        );
        vm.etch(MOCK_CONSUMER, new bytes(10));
        vm.expectRevert();
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage{gas: gasInsufficientForCheck}(
            MOCK_VRF_PROVIDER_BLOCKCHAIN_ID, MOCK_VRF_PROVIDER_ADDRESS, abi.encode(response)
        );
    }

    function testReceiveTeleporterMessageInsufficientGasForCall() public {
        // Place a request from the expected consumer.
        uint32 callbackGasLimit = 100_000;
        uint256 requestID = _makeRandomWordsRequest(MOCK_CONSUMER, callbackGasLimit);

        // Format the response.
        VRFResponseInfo memory response =
            VRFResponseInfo({requestID: requestID, randomWords: new uint256[](1), callbackGasLimit: callbackGasLimit});

        // Expect it to revert if the call to receiveTeleporterMessage doesn't have sufficient gas for the callback gas limit.
        VRFConsumer consumer;
        vm.mockCall(
            MOCK_CONSUMER,
            abi.encodeWithSelector(consumer.rawFulfillRandomWords.selector, requestID, new uint256[](1)),
            new bytes(0)
        );
        vm.expectRevert();
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage{gas: callbackGasLimit - 1}(
            MOCK_VRF_PROVIDER_BLOCKCHAIN_ID, MOCK_VRF_PROVIDER_ADDRESS, abi.encode(response)
        );
    }

    function testReceiveTeleporterMessageRequesterIsNotContract() public {
        // Place a request from the expected consumer.
        uint32 callbackGasLimit = 100_000;
        uint256 requestID = _makeRandomWordsRequest(MOCK_CONSUMER, callbackGasLimit);

        // Format the message to be received.
        VRFResponseInfo memory response =
            VRFResponseInfo({requestID: requestID, randomWords: new uint256[](1), callbackGasLimit: callbackGasLimit});

        // Mock the consumer/requesting being an EOA with no code.
        vm.etch(MOCK_CONSUMER, new bytes(0));

        // Expect it to revert.
        vm.expectRevert();
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage(
            MOCK_VRF_PROVIDER_BLOCKCHAIN_ID, MOCK_VRF_PROVIDER_ADDRESS, abi.encode(response)
        );
    }

    function _addConsumer(address consumer) private {
        vm.expectEmit(true, true, true, true, address(vrfProxy));
        emit ConsumerAdded(consumer);
        consumers[0] = consumer;
        vrfConsumerRegistry.addConsumers(consumers);
        assertTrue(vrfConsumerRegistry.isValid(consumer));
    }

    function _makeRandomWordsRequest(address requester, uint32 callbackGasLimit) internal returns (uint256) {
        _addConsumer(requester);
        vm.mockCall(
            MOCK_TELEPOTER_MESSENGER_ADDRESS,
            abi.encodeWithSelector(ITeleporterMessenger.sendCrossChainMessage.selector),
            abi.encode(bytes32(0))
        );
        vm.prank(requester);
        return vrfProxy.requestRandomWords(1, callbackGasLimit, 1);
    }
}
