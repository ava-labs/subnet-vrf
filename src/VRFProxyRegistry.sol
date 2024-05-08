// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "./interfaces/IVRFProxyRegistry.sol";
import "@openzeppelin/contracts@4.8.1/access/Ownable.sol";

contract VRFProxyRegistry is IVRFProxyRegistry, Ownable {

    mapping(bytes32 blockchainId => mapping(address proxy => bool approved)) public isValid;

    function addProxies(bytes32 blockchainId, address[] calldata proxies) external onlyOwner {
        if (blockchainId == bytes32(0)) revert();
        uint256 length = proxies.length; // gas opt
        for (uint256 i; i < length; i++) {
            address proxy = proxies[i];
            if (!isValid[blockchainId][proxy] && proxy != address(0)) {
                isValid[blockchainId][proxy] = true;
                emit ProxyAdded(blockchainId, proxy);
            }
        }
    }

    function removeProxies(bytes32 blockchainId, address[] calldata proxies) external onlyOwner {
        if (blockchainId == bytes32(0)) revert();
        uint256 length = proxies.length; // gas opt
        for (uint256 i; i < length; i++) {
            address proxy = proxies[i];
            if (isValid[blockchainId][proxy] && proxy != address(0)) {
                delete isValid[blockchainId][proxy];
                emit ProxyRemoved(blockchainId, proxy);
            }
        }
    }
}
