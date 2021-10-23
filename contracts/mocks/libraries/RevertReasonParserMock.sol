// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v1;

/** @title Library that allows to parse unsuccessful arbitrary calls revert reasons.
  * See https://solidity.readthedocs.io/en/latest/control-structures.html#revert for details.
  * Note that we assume revert reason being abi-encoded as Error(string) so it may fail to parse reason
  * if structured reverts appear in the future.
  *
  * All unsuccessful parsings get encoded as Unknown(data) string
  */
contract RevertReasonParserMock {
    bytes4 constant private _ERROR_SELECTOR = bytes4(keccak256("Error(string)"));
    bytes4 constant private _PANIC_SELECTOR = bytes4(keccak256("Panic(uint256)"));

    function parse(bytes memory data, string memory prefix) public pure returns (string memory) {
        // https://solidity.readthedocs.io/en/latest/control-structures.html#revert
        // We assume that revert reason is abi-encoded as Error(string)
        bytes4 selector;
        assembly {  // solhint-disable-line no-inline-assembly
            selector := mload(add(data, 0x20))
        }
        // 68 = 4-byte selector + 32 bytes offset + 32 bytes length
        if (selector == _ERROR_SELECTOR && data.length >= 68) {
            string memory reason;
            // solhint-disable no-inline-assembly
            assembly {
                // 68 = 32 bytes data length + 4-byte selector + 32 bytes offset
                reason := add(data, 68)
            }
            /*
                revert reason is padded up to 32 bytes with ABI encoder: Error(string)
                also sometimes there is extra 32 bytes of zeros padded in the end:
                https://github.com/ethereum/solidity/issues/10170
                because of that we can't check for equality and instead check
                that string length + extra 68 bytes is less than overall data length
            */
            require(data.length >= 68 + bytes(reason).length, "Invalid revert reason");
            return string(abi.encodePacked(prefix, "Error(", reason, ")"));
        }
        // 36 = 4-byte selector + 32 bytes integer
        else if (selector == _PANIC_SELECTOR && data.length == 36) {
            uint256 code;
            // solhint-disable no-inline-assembly
            assembly {
                // 36 = 32 bytes data length + 4-byte selector
                code := mload(add(data, 36))
            }
            return string(abi.encodePacked(prefix, "Panic(", _toHex(code), ")"));
        }
        return string(abi.encodePacked(prefix, "Unknown(", _toHex(data), ")"));
    }

    // solhint-disable private-vars-leading-underscore
    function _toHex(uint256 value) public pure returns(string memory) {
        return _toHex(abi.encodePacked(value));
    }

    // solhint-disable private-vars-leading-underscore
    function _toHex(bytes memory data) public pure returns(string memory) {
        bytes16 alphabet = 0x30313233343536373839616263646566;
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 * i + 2] = alphabet[uint8(data[i] >> 4)];
            str[2 * i + 3] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}