// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts@5.0.2/token/ERC20/ERC20.sol";

interface ERC677Receiver {
    function onTokenTransfer(address sender, uint256 value, bytes calldata data) external;
}

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES UNAUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
abstract contract ERC677Token is ERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);

    /**
     * @dev transfer token to a contract address with additional data if the recipient is a contact.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     * @param data The extra data to be passed to the receiving contract.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) public virtual returns (bool success) {
        super.transfer(to, value);
        emit Transfer(msg.sender, to, value, data);
        if (_isContract(to)) {
            _contractFallback(to, value, data);
        }
        return true;
    }

    // PRIVATE
    function _contractFallback(address to, uint256 value, bytes calldata data) private {
        ERC677Receiver receiver = ERC677Receiver(to);
        receiver.onTokenTransfer(msg.sender, value, data);
    }

    function _isContract(address addr) private view returns (bool hasCode) {
        uint256 length;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            length := extcodesize(addr)
        }
        return length > 0;
    }
}

contract LinkToken is ERC677Token {
    error InvalidRecipient();

    // MODIFIERS
    modifier validRecipient(address recipient) {
        if (recipient == address(0) || recipient == address(this)) revert InvalidRecipient();
        _;
    }

    constructor() ERC20("LINK", "ChainLinkToken") {
        _mint(msg.sender, 10 ** 27);
    }

    /**
     * @dev transfer token to a specified address with additional data if the recipient is a contract.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     * @param data The extra data to be passed to the receiving contract.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data)
        public
        override
        validRecipient(to)
        returns (bool success)
    {
        return super.transferAndCall(to, value, data);
    }

    /**
     * @dev transfer token to a specified address.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address to, uint256 value) public override validRecipient(to) returns (bool success) {
        return super.transfer(to, value);
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public override validRecipient(spender) returns (bool) {
        return super.approve(spender, value);
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public override validRecipient(to) returns (bool) {
        return super.transferFrom(from, to, value);
    }
}
