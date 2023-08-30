// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/console.sol";

// Internal Dependencies
import {IOrchestrator} from "src/orchestrator/IOrchestrator.sol";

// SuT
import {
    BondingCurveFundingManagerBase,
    IBondingCurveFundingManagerBase
} from
    "src/modules/fundingManager/bondingCurveFundingManager/BondingCurveFundingManagerBase.sol";
import {IBancorFormula} from
    "src/modules/fundingManager/bondingCurveFundingManager/formula/IBancorFormula.sol";
import {Module} from "src/modules/base/Module.sol";

contract BondingCurveFundingManagerMock is BondingCurveFundingManagerBase {
    IBancorFormula public formula;

    function init(
        IOrchestrator orchestrator_,
        Metadata memory metadata,
        bytes memory configData
    ) external override(Module) initializer {
        __Module_init(orchestrator_, metadata);

        (
            bytes32 _name,
            bytes32 _symbol,
            uint8 _decimals,
            address _formula,
            uint _buyFee,
            bool _buyIsOpen
        ) = abi.decode(
            configData, (bytes32, bytes32, uint8, address, uint, bool)
        );

        __ERC20_init(
            string(abi.encodePacked(_name)), string(abi.encodePacked(_symbol))
        );

        formula = IBancorFormula(_formula);

        _setTokenDecimals(_decimals);

        _setBuyFee(_buyFee);

        if (_buyIsOpen == true) _openBuy();
    }

    function _issueTokensFormulaWrapper(uint _depositAmount)
        internal
        view
        override(BondingCurveFundingManagerBase)
        returns (uint)
    {
        // Since this is a mock, we will always mint the same amount of tokens as have been deposited
        // Integration tests using the actual Formula can be found in the BancorFormulaFundingManagerTest.t.sol
        return _depositAmount;

        /* uint32 connectorWeight = 1000; // Mock value, needs to be calculated
        return formula.calculatePurchaseReturn(
            totalSupply(),
            __Module_orchestrator.token().balanceOf(address(this)),
            connectorWeight,
            _depositAmount
        ); */
    }

    //--------------------------------------------------------------------------
    // Mock access for internal functions

    function call_calculateFeeDeductedDepositAmount(
        uint _depositAmount,
        uint _feePct
    ) external pure returns (uint) {
        return _calculateFeeDeductedDepositAmount(_depositAmount, _feePct);
    }

    function call_BPS() external pure returns (uint) {
        return BPS;
    }
}
