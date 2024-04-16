// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

// External Interfaces
import {IERC20Issuance} from "./IERC20Issuance.sol";

// External Dependencies
import {ERC20Upgradeable} from "@oz-up/token/ERC20/ERC20Upgradeable.sol";
import {ContextUpgradeable} from "@oz-up/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@oz-up/access/OwnableUpgradeable.sol";

// External Libraries
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

/// @title Bonding Curve Funding Manager Base Contract.
/// @author Inverter Network.
/// @notice This contract enables the base functionalities for issuing tokens along a bonding curve.
/// @dev The contract implements functionalties for:
///         - opening and closing the issuance of tokens.
///         - setting and subtracting of fees, expressed in BPS and subtracted from the collateral.
///         - calculating the issuance amount by means of an abstract function to be implemented in
///             the downstream contract.
contract ERC20Issuance is
    IERC20Issuance,
    ERC20Upgradeable,
    OwnableUpgradeable
{
    // State Variables
    address public allowedMinter;
    uint public MAX_SUPPLY;
    uint8 internal _decimals;

    //------------------------------------------------------------------------------------
    // Modifiers
    modifier onlyMinter() {
        if (_msgSender() != allowedMinter) {
            revert IERC20Issuance__CallerIsNotMinter();
        }
        _;
    }

    //------------------------------------------------------------------------------------
    // Initializer

    function init(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint MAX_SUPPLY_,
        address admin_
    ) external virtual initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init(admin_);
        _setMinter(admin_);
        MAX_SUPPLY = MAX_SUPPLY_;
        _decimals = decimals_;
    }

    //------------------------------------------------------------------------------------
    // External Functions

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc IERC20Issuance
    function setMinter(address _minter) external onlyOwner {
        _setMinter(_minter);
    }

    /// @inheritdoc IERC20Issuance
    function mint(address _to, uint _amount) external onlyMinter {
        if (totalSupply() + _amount > MAX_SUPPLY) {
            revert IERC20Issuance__MintExceedsSupplyCap();
        }
        _mint(_to, _amount);
    }

    /// @inheritdoc IERC20Issuance
    function burn(address _from, uint _amount) external onlyMinter {
        _burn(_from, _amount);
    }

    //------------------------------------------------------------------------------------
    // Internal Functions

    /// @notice Sets the address of the minter.
    /// @param _minter The address of the minter.
    function _setMinter(address _minter) internal {
        allowedMinter = _minter;
        emit minterSet(_minter);
    }
}