// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice Represents all of the relevant information for a given
 * VRF request message to the VRF partner on a partner chain. This
 * struct is ABI encoded/decoded in the Teleporter message passing.
 */
struct VRFRequestInfo {
    uint256 requestID;
    uint16 minimumRequestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;
    address consumer;
}

/**
 * @notice Represents all of the relevant information for a given VRF
 * response message received back from the VRF provided on a partner chain.
 * This struct is ABI encoded/decoded in the Teleporter message passing.
 */
struct VRFResponseInfo {
    uint256 requestID;
    uint256[] randomWords;
    uint32 callbackGasLimit;
}
