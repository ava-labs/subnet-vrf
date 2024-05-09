// SPDX-License-IDentifier: UNLICENSED
pragma solidity 0.8.18;

import {IVRFProxyRegistry} from "./interfaces/IVRFProxyRegistry.sol";
import {Ownable} from "@openzeppelin/contracts@4.8.1/access/Ownable.sol";

contract VRFProxyRegistry is IVRFProxyRegistry, Ownable {

    mapping(bytes32 blockchainID => mapping(address proxy => bool approved)) public isValid;

    function addProxies(bytes32 blockchainID, address[] calldata proxies) external onlyOwner {
        if (blockchainID == bytes32(0)) revert();
        uint256 length = proxies.length; // gas opt
        for (uint256 i; i < length; i++) {
            address proxy = proxies[i];
            if (!isValid[blockchainID][proxy] && proxy != address(0)) {
                isValid[blockchainID][proxy] = true;
                emit ProxyAdded(blockchainID, proxy);
            }
        }
    }

    function removeProxies(bytes32 blockchainID, address[] calldata proxies) external onlyOwner {
        if (blockchainID == bytes32(0)) revert();
        uint256 length = proxies.length; // gas opt
        for (uint256 i; i < length; i++) {
            address proxy = proxies[i];
            if (isValid[blockchainID][proxy] && proxy != address(0)) {
                delete isValid[blockchainID][proxy];
                emit ProxyRemoved(blockchainID, proxy);
            }
        }
    }
}
