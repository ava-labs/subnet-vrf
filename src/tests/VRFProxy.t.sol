// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {VRFProxy, IVRFProxy} from "../VRFProxy.sol";
import {VRFRequestInfo, VRFResponseInfo} from "../interfaces/IVRF.sol";
import {VRFConsumerRegistry} from "../VRFConsumerRegistry.sol";
import {TeleporterRegistry} from "@teleporter/contracts/src/Teleporter/upgrades/TeleporterRegistry.sol";
import {
    ITeleporterMessenger,
    TeleporterMessageInput,
    TeleporterFeeInfo
} from "@teleporter/contracts/src/Teleporter/ITeleporterMessenger.sol";
import {VRFConsumer} from "../mocks/VRFConsumer.sol";

contract VRFProxyTest is Test {
    address public constant MOCK_TELEPOTER_MESSENGER_ADDRESS = address(0x1111);
    uint256 public constant MOCK_LATEST_TELEPORTER_VERSION = 1;
    address public constant MOCK_TELEPORTER_REGISTRY_ADDRESS = address(0x2222);
    bytes32 public constant MOCK_VRF_PROVIDER_BLOCKCHAIN_ID =
        bytes32(hex"1234567812345678123456781234567812345678123456781234567812345678");
    address public constant MOCK_VRF_PROVIDER_ADDRESS = address(0x3333);
    address public constant MOCK_CONSUMER = address(0x4444);
    address public constant NON_OWNER_ADDRESS = address(0x6666);

    VRFConsumerRegistry public vrfConsumerRegistry;
    VRFProxy public vrfProxy;

    address[] public managers;
    address[] public consumers;

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

        managers = new address[](1);
        managers[0] = address(this);

        consumers = new address[](1);
        consumers[0] = MOCK_CONSUMER;

        vrfConsumerRegistry = new VRFConsumerRegistry(address(this), managers);

        vrfProxy = new VRFProxy(
            MOCK_TELEPORTER_REGISTRY_ADDRESS,
            address(vrfConsumerRegistry),
            MOCK_VRF_PROVIDER_BLOCKCHAIN_ID,
            MOCK_VRF_PROVIDER_ADDRESS
        );
    }

    function testAddConsumerSucess() public {
        _addConsumer(MOCK_CONSUMER);
    }

    function testAddConsumerZeroAddress() public {
        consumers[0] = address(0);
        vrfConsumerRegistry.addConsumers(consumers);
        assertFalse(vrfConsumerRegistry.isApprovedConsumer(address(0)));
    }

    function testAddConsumerNotOwner() public {
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000006666 is missing role 0x795edd50d89cf0f09d5fb90f6c834853abd2897512ea74c56cf89c0a94b5da8b"
        );
        vm.prank(NON_OWNER_ADDRESS);
        vrfConsumerRegistry.addConsumers(consumers);
    }

    function addConsumerAlreadyAdded() public {
        assertTrue(vrfConsumerRegistry.isApprovedConsumer(MOCK_CONSUMER));
        _addConsumer(MOCK_CONSUMER);
        vrfConsumerRegistry.addConsumers(consumers);
        // Nothing changes - no events emitted
        assertEq(vm.getRecordedLogs().length, 0);
        assertTrue(vrfConsumerRegistry.isApprovedConsumer(MOCK_CONSUMER));
    }

    function testRemoveConsumerSuccess() public {
        // Add a consumer.
        _addConsumer(MOCK_CONSUMER);

        // Remove the consumer.
        vm.expectEmit(true, true, true, true, address(vrfConsumerRegistry));
        emit ConsumerRemoved(MOCK_CONSUMER);
        vrfConsumerRegistry.removeConsumers(consumers);
        assertFalse(vrfConsumerRegistry.isApprovedConsumer(MOCK_CONSUMER));
    }

    function testRemoveConsumerNotFound() public {
        // Try to remove the consumer that was never added.
        vrfConsumerRegistry.removeConsumers(consumers);
        // Nothing changes - no events emitted
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function testRemoveConsumerNotOwner() public {
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000006666 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        // NON_OWNER_ADDRESS does not have the DEFAULT_ADMIN_ROLE
        vm.prank(NON_OWNER_ADDRESS);
        vrfConsumerRegistry.removeConsumers(consumers);
    }

    function testRequestRandomWordsSuccess() public {
        // Add this contract as a consumer to be able to request values.
        _addConsumer(address(this));

        // Initialize needed data.
        uint256 expectedRequestID = vrfProxy.requestNonce() + 1;
        uint16 mockMinConfs = 1;
        uint32 mockCallbackGasLimit = 213_000;
        uint32 mockNumWords = 20;

        // Construct a request.
        VRFRequestInfo memory expectedRequest = VRFRequestInfo({
            requestID: expectedRequestID,
            minimumRequestConfirmations: mockMinConfs,
            callbackGasLimit: mockCallbackGasLimit,
            numWords: mockNumWords,
            consumer: address(this)
        });
        // Construct the teleporter message input.
        TeleporterMessageInput memory tmi = TeleporterMessageInput({
            destinationBlockchainID: MOCK_VRF_PROVIDER_BLOCKCHAIN_ID,
            destinationAddress: MOCK_VRF_PROVIDER_ADDRESS,
            feeInfo: TeleporterFeeInfo({feeTokenAddress: address(0), amount: 0}),
            requiredGasLimit: vrfProxy.VRF_REQUEST_REQUIRED_GAS(),
            allowedRelayerAddresses: new address[](0),
            message: abi.encode(expectedRequest)
        });

        // Create precise mock call and expectation.
        vm.mockCall(
            MOCK_TELEPOTER_MESSENGER_ADDRESS,
            abi.encodeCall(ITeleporterMessenger.sendCrossChainMessage, (tmi)),
            abi.encode(bytes32(0))
        );
        vm.expectCall(
            MOCK_TELEPOTER_MESSENGER_ADDRESS, abi.encodeCall(ITeleporterMessenger.sendCrossChainMessage, (tmi))
        );

        // Expect the event, and its data to be precise
        vm.expectEmit(true, true, true, true, address(vrfProxy));
        emit RandomWordsRequested({
            requestID: expectedRequestID,
            requester: address(this),
            minimumRequestConfirmations: mockMinConfs,
            callbackGasLimit: mockCallbackGasLimit,
            numWords: mockNumWords
        });

        // Request random words and assert validity of the requestID.
        uint256 requestID = vrfProxy.requestRandomWords(mockMinConfs, mockCallbackGasLimit, mockNumWords);
        assertEq(requestID, expectedRequestID);
    }

    function testRequestRandomWordsNotAnApprovedConsumer() public {
        vm.expectRevert(IVRFProxy.CallerIsNotAnApprovedConsumer.selector);
        // address(this) is not an approved consumer
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
            MOCK_CONSUMER, abi.encodeCall(consumer.rawFulfillRandomWords, (requestID, mockValues)), new bytes(0)
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
            MOCK_CONSUMER, abi.encodeCall(consumer.rawFulfillRandomWords, (requestID, mockValues)), new bytes(0)
        );
        vm.expectCall(
            MOCK_CONSUMER, 0, callbackGasLimit, abi.encodeCall(consumer.rawFulfillRandomWords, (requestID, mockValues))
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
        vm.expectRevert(IVRFProxy.InvalidSourceBlockchainID.selector);
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage(otherBlockchainID, MOCK_VRF_PROVIDER_ADDRESS, new bytes(0));
    }

    function testReceiveTeleporterMessageInvalidAddress() public {
        address otherAddress = address(0xbeef);
        vm.expectRevert(IVRFProxy.CallerNotVRFProvider.selector);
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vrfProxy.receiveTeleporterMessage(MOCK_VRF_PROVIDER_BLOCKCHAIN_ID, otherAddress, new bytes(0));
    }

    function testReceiveTeleporterMessageInvalidRequester() public {
        // Receive a message for a request ID that is not associated with any request.
        VRFResponseInfo memory response =
            VRFResponseInfo({requestID: 42, randomWords: new uint256[](1), callbackGasLimit: 10_000});

        vm.expectRevert(IVRFProxy.InvalidRequestID.selector);
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
            MOCK_CONSUMER, abi.encodeCall(consumer.rawFulfillRandomWords, (requestID, new uint256[](1))), new bytes(0)
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

    function _addConsumer(address consumer) private {
        vm.expectEmit(true, true, true, true, address(vrfConsumerRegistry));
        emit ConsumerAdded(consumer);
        consumers[0] = consumer;
        vrfConsumerRegistry.addConsumers(consumers);
        assertTrue(vrfConsumerRegistry.isApprovedConsumer(consumer));
    }
}
