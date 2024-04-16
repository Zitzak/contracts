// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/console.sol";

// Internal Dependencies
import {IOrchestrator} from "src/orchestrator/IOrchestrator.sol";

// SuT
import {RestrictedBancorVirtualSupplyBondingCurveFundingManager} from
    "src/modules/fundingManager/bondingCurveFundingManager/ParibuChanges/RestrictedBancorVirtualSupplyBondingCurveFundingManager.sol";

import {
    BancorVirtualSupplyBondingCurveFundingManager,
    IBancorVirtualSupplyBondingCurveFundingManager
} from
    "src/modules/fundingManager/bondingCurveFundingManager/BancorVirtualSupplyBondingCurveFundingManager.sol";
import {IBancorFormula} from
    "src/modules/fundingManager/bondingCurveFundingManager/formula/IBancorFormula.sol";
import {Module} from "src/modules/base/Module.sol";

contract RestrictedBancorVirtualSupplyBondingCurveFundingManagerMock is
    RestrictedBancorVirtualSupplyBondingCurveFundingManager
{
    //--------------------------------------------------------------------------
    // The BancorVirtualSupplyBondingCurveFundingManager is not abstract, so all the necessary functions are already implemented
    // The goal of this mock is to provide direct access to internal functions for testing purposes.

    //--------------------------------------------------------------------------
    // Mock access for internal functions

    function call_BPS() external pure returns (uint) {
        return BPS;
    }

    function call_PPM() external pure returns (uint32) {
        return PPM;
    }

    function call_reserveRatioForBuying() external view returns (uint32) {
        return reserveRatioForBuying;
    }

    function call_reserveRatioForSelling() external view returns (uint32) {
        return reserveRatioForSelling;
    }

    function call_collateralTokenDecimals() external view returns (uint8) {
        return collateralTokenDecimals;
    }

    function call_issuanceTokenDecimals() external view returns (uint8) {
        return issuanceTokenDecimals;
    }

    // Since the init calls are not registered for coverage, we call expose setIssuanceToken to get to 100% test coverage.
    function call_setIssuanceToken(address _newIssuanceToken) external {
        _setIssuanceToken(_newIssuanceToken);
    }

    function call_staticPricePPM(
        uint _issuanceTokenSupply,
        uint _collateralSupply,
        uint32 _reserveRatio
    ) external pure returns (uint) {
        return _staticPricePPM(
            _issuanceTokenSupply, _collateralSupply, _reserveRatio
        );
    }

    function call_convertAmountToRequiredDecimal(
        uint _amount,
        uint8 _tokenDecimals,
        uint8 _requiredDecimals
    ) external pure returns (uint) {
        return _convertAmountToRequiredDecimal(
            _amount, _tokenDecimals, _requiredDecimals
        );
    }

    function call_mintIssuanceToken(uint _amount, address _receiver) external {
        _mint(_receiver, _amount);
    }

    // Note: this function returns the virtual token supply in the same format it will be fed to the Bancor formula
    function call_getFormulaVirtualTokenSupply() external view returns (uint) {
        uint decimalConvertedVirtualTokenSupply =
        _convertAmountToRequiredDecimal(
            virtualTokenSupply, issuanceTokenDecimals, 18
        );
        return decimalConvertedVirtualTokenSupply;
    }

    // Note: this function returns the virtual collateral supply in the same format it will be fed to the Bancor formula
    function call_getFormulaVirtualCollateralSupply()
        external
        view
        returns (uint)
    {
        uint decimalConvertedVirtualCollateralSupply =
        _convertAmountToRequiredDecimal(
            virtualCollateralSupply, collateralTokenDecimals, 18
        );
        return decimalConvertedVirtualCollateralSupply;
    }
}