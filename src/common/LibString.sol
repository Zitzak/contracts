// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

library LibString {
    /// @dev Returns true if string `a` equals string `b`.
    function equals(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        if (bytes(a).length != bytes(b).length) {
            return false;
        } else {
            return keccak256(bytes(a)) == keccak256(bytes(b));
        }
    }
}