// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {VRFProvider} from "../VRFProvider.sol";
import {VRFProxyRegistry} from "../VRFProxyRegistry.sol";
import {LinkToken} from "../mocks/LinkToken.sol";
import {VRFRequestInfo, VRFResponseInfo} from "../interfaces/IVRF.sol";
import {VRFV2WrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import {TeleporterRegistry} from "@teleporter/contracts/src/Teleporter/upgrades/TeleporterRegistry.sol";
import {
    ITeleporterMessenger,
    TeleporterMessageInput,
    TeleporterFeeInfo
} from "@teleporter/contracts/src/Teleporter/ITeleporterMessenger.sol";

contract VRFProviderTest is Test {
    address public constant MOCK_TELEPOTER_MESSENGER_ADDRESS = address(0x1111);
    uint256 public constant MOCK_LATEST_TELEPORTER_VERSION = 1;
    address public constant MOCK_TELEPORTER_REGISTRY_ADDRESS = address(0x2222);
    address public constant MOCK_CHAINLINK_VRF_WRAPPER_ADDRESS = address(0x3333);
    bytes32 public constant MOCK_VRF_PROXY_BLOCKCHAIN_ID =
        bytes32(hex"1234567812345678123456781234567812345678123456781234567812345678");
    address public constant MOCK_VRF_PROXY_ADDRESS = address(0x4444);

    address[] public managers;
    address[] public proxies;

    VRFProvider public provider;
    VRFProxyRegistry public vrfProxyRegistry;
    LinkToken public linkToken;

    // Event emitted by VRFProvider
    event VRFRequestReceived(uint256 indexed proxyRequestID, uint256 indexed chainlinkVRFRequestID, uint32 numWords);
    event VRFRequestFulfilled(uint256 indexed proxyRequestID, uint256 indexed chainlinkVRFRequestID, uint32 numWords);

    function setUp() public virtual {
        managers = new address[](1);
        managers[0] = address(this);
        proxies = new address[](1);

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
        vrfProxyRegistry = new VRFProxyRegistry(address(this), managers);
        linkToken = new LinkToken();
        provider = new VRFProvider(
            MOCK_TELEPORTER_REGISTRY_ADDRESS,
            address(vrfProxyRegistry),
            MOCK_CHAINLINK_VRF_WRAPPER_ADDRESS,
            address(linkToken)
        );
    }

    function testReceiveTeleporterMessageSuccess() public {
        VRFRequestInfo memory mockRequestInfo = _getMockVRFRequestInfo();
        uint256 mockChainlinkVRFRequestID = 111222;
        _submitVRFRequest(mockRequestInfo, mockChainlinkVRFRequestID);
    }

    function testReceiveTeleporterMessageInvalidSourceBlockchainID() public {
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vm.expectRevert("VRFProvider: invalid source blockchain ID");
        bytes32 otherBlockchainID = bytes32(hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        provider.receiveTeleporterMessage(
            otherBlockchainID, MOCK_VRF_PROXY_ADDRESS, abi.encode(_getMockVRFRequestInfo())
        );
    }

    function testReceiveTeleporterMessageInvalidProxyAddress() public {
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vm.expectRevert("VRFProvider: invalid origin sender address");
        address otherProxyAddress = address(0x5555);
        provider.receiveTeleporterMessage(
            MOCK_VRF_PROXY_BLOCKCHAIN_ID, otherProxyAddress, abi.encode(_getMockVRFRequestInfo())
        );
    }

    function testReceiveTeleporterMessageInvalidProxyRequestID() public {
        VRFRequestInfo memory mockRequestInfo = _getMockVRFRequestInfo();
        mockRequestInfo.requestID = 0;
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vm.expectRevert("VRFProvider: invalid proxy request ID");
        provider.receiveTeleporterMessage(
            MOCK_VRF_PROXY_BLOCKCHAIN_ID, MOCK_VRF_PROXY_ADDRESS, abi.encode(mockRequestInfo)
        );
    }

    function testFulfillRandomWordsSuccess() public {
        // Place a mock VRF request to be fulfilled.
        VRFRequestInfo memory mockRequestInfo = _getMockVRFRequestInfo();
        mockRequestInfo.numWords = 2;
        uint256 mockChainlinkVRFRequestID = 333444;
        _submitVRFRequest(mockRequestInfo, mockChainlinkVRFRequestID);

        // Fulfill the request with a mock value.
        uint256[] memory mockRandomWords = new uint256[](mockRequestInfo.numWords);
        mockRandomWords[0] = 7777;
        mockRandomWords[1] = 8888;
        vm.expectEmit(true, true, true, true, address(provider));
        emit VRFRequestFulfilled(mockRequestInfo.requestID, mockChainlinkVRFRequestID, mockRequestInfo.numWords);
        vm.mockCall(
            MOCK_TELEPOTER_MESSENGER_ADDRESS,
            abi.encodeWithSelector(ITeleporterMessenger.sendCrossChainMessage.selector),
            abi.encode(bytes32(0))
        );
        VRFResponseInfo memory expectedResponse = VRFResponseInfo({
            requestID: mockRequestInfo.requestID,
            randomWords: mockRandomWords,
            callbackGasLimit: mockRequestInfo.callbackGasLimit
        });
        vm.expectCall(
            MOCK_TELEPOTER_MESSENGER_ADDRESS,
            abi.encodeWithSelector(
                ITeleporterMessenger.sendCrossChainMessage.selector,
                TeleporterMessageInput({
                    destinationBlockchainID: MOCK_VRF_PROXY_BLOCKCHAIN_ID,
                    destinationAddress: MOCK_VRF_PROXY_ADDRESS,
                    feeInfo: TeleporterFeeInfo({feeTokenAddress: address(0), amount: 0}),
                    requiredGasLimit: mockRequestInfo.callbackGasLimit + provider.TELEPORTER_RECEIVE_MESSAGE_GAS_OVERHEAD(),
                    allowedRelayerAddresses: new address[](0),
                    message: abi.encode(expectedResponse)
                })
            )
        );
        vm.prank(MOCK_CHAINLINK_VRF_WRAPPER_ADDRESS);
        provider.rawFulfillRandomWords(mockChainlinkVRFRequestID, mockRandomWords);
    }

    function testFulfillRandomWordsInvalidChainlinkVRFRequestID() public {
        // Fulfill the request that doesn't exist.
        uint256[] memory mockRandomWords = new uint256[](1);
        mockRandomWords[0] = 1234;
        vm.expectRevert("VRFProvider: invalid Chainlink VRF request ID");
        vm.prank(MOCK_CHAINLINK_VRF_WRAPPER_ADDRESS);
        provider.rawFulfillRandomWords(123, mockRandomWords);
    }

    function _submitVRFRequest(VRFRequestInfo memory request, uint256 mockChainlinkVRFRequestID) internal {
        vm.prank(MOCK_TELEPOTER_MESSENGER_ADDRESS);
        vm.expectEmit(true, true, true, true, address(provider));
        emit VRFRequestReceived(request.requestID, mockChainlinkVRFRequestID, request.numWords);
        provider.receiveTeleporterMessage(MOCK_VRF_PROXY_BLOCKCHAIN_ID, MOCK_VRF_PROXY_ADDRESS, abi.encode(request));
    }

    function _getMockVRFRequestInfo() internal pure returns (VRFRequestInfo memory) {
        return VRFRequestInfo({
            requestID: 543,
            minimumRequestConfirmations: 200,
            callbackGasLimit: 200_000,
            numWords: 1
        });
    }
}
