// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.19;

// Internal Dependencies
import {Module} from "src/modules/base/Module.sol";

// Internal Interfaces
import {IOrchestrator} from "src/orchestrator/IOrchestrator.sol";

import {
    IStakingManager,
    StakingManager,
    SafeERC20,
    IERC20,
    ReentrancyGuard
} from "./StakingManager.sol";

import {
    IOptimisticOracleIntegrator,
    OptimisticOracleIntegrator,
    OptimisticOracleV3CallbackRecipientInterface,
    OptimisticOracleV3Interface,
    ClaimData
} from "./oracle/OptimisticOracleIntegrator.sol";

contract KPIRewarder is StakingManager, OptimisticOracleIntegrator {
    using SafeERC20 for IERC20;

    event StakeEnqueued(address sender, uint amount);

    error Module__KPIRewarder__InvalidTrancheNumber();
    error Module__KPIRewarder__InvalidKPIValueLengths();
    error Module__KPIRewarder__InvalidKPIValues();

    error Module__KPIRewarder__StakingQueueIsFull();

    bytes32 public constant ASSERTION_MANAGER = "ASSERTION_MANAGER";
    uint public constant MAX_QUEUE_LENGTH = 50;

    uint KPICounter;

    uint activeKPI;
    uint activeTargetValue;

    DataAssertion activeAssertion;

    mapping(uint => KPI) registryOfKPIs;
    mapping(bytes32 => RewardRoundConfiguration) assertionConfig;

    // assertionId => extra data for the rewarder
    //mapping(bytes32 => RewarderAssertion) assertionRewarderRegistry;

    // Deposit Queue
    struct QueuedStake {
        address stakerAddress;
        uint amount;
    }

    QueuedStake[] public stakingQueue;
    uint public totalQueuedFunds;

    /*
    Tranche Example:
    trancheValues = [10000, 20000, 30000]
    trancheRewards = [100, 200, 100]
    continuous = false
     ->   if KPI is 12345, reward is 100 for the tanche [0-10000]
     ->   if KPI is 32198, reward is 400 for the tanches [0-10000, 10000-20000 and 20000-30000]

    if continuous = true
    ->    if KPI is 15000, reward is 200 for the tanches [100% 0-10000, 50% * 10000-15000]
    ->    if KPI is 25000, reward is 350 for the tanches [100% 0-10000, 100% 10000-20000, 50% 20000-30000]

    */
    struct KPI {
        uint creationTime; // timestamp the KPI was created //
        uint numOfTranches; // number of tranches the KPI is divided into
        bool continuous; // should the tranche rewards be distributed continuously or in steps
        uint[] trancheValues; // The value at which a tranche ends
        uint[] trancheRewards; // The rewards to be dsitributed at completion of each tranche
    }

    struct RewardRoundConfiguration {
        uint creationTime; // timestamp the assertion was created
        uint assertedValue; // the value that was asserted
        uint KpiToUse; // the KPI to be used for distribution once the assertion confirms
        bool distributed;
    }

    /// @inheritdoc Module
    function init(
        IOrchestrator orchestrator_,
        Metadata memory metadata,
        bytes memory configData
    )
        external
        virtual
        override(StakingManager, OptimisticOracleIntegrator)
        initializer
    {
        __Module_init(orchestrator_, metadata);

        (address stakingTokenAddr, address currencyAddr, address ooAddr) =
            abi.decode(configData, (address, address, address));

        _setStakingToken(stakingTokenAddr);

        // TODO ERC165 Interface Validation for the OO, for now it just reverts
        oo = OptimisticOracleV3Interface(ooAddr);
        defaultIdentifier = oo.defaultIdentifier();

        setDefaultCurrency(currencyAddr);
        setOptimisticOracle(ooAddr);
    }

    // Assertion Manager functions:
    function setAssertion(bytes32 dataId, bytes32 data, address asserter) external onlyModuleRole(ASSERTION_MANAGER) {
        // TODO stores the assertion that will be posted to the Optimistic Oracle
        // needs to store locally the numeric value to be asserted. the amount to distribute and the distribution time
        
        //TODO: inputs
        // TODO: what kind of checks do we want to implement? Technically the value in "data" wouldn't need to be the sam as assertedValue...
        
        activeAssertion = DataAssertion( dataId,  data,  asserter, false);   
    }

    function postAssertion()
        external
        onlyModuleRole(ASSERTION_MANAGER)
        returns (bytes32 assertionId)
    {
        // performs staking for all users in queue
        for (uint i = 0; i < stakingQueue.length; i++) {
            _stake(stakingQueue[i].stakerAddress, stakingQueue[i].amount);
            totalQueuedFunds -= stakingQueue[i].amount;
        }

        // resets the queue
        delete stakingQueue;
        totalQueuedFunds = 0;

        // TODO posts the assertion to the Optimistic Oracle
        // Takes the payout from the FundingManager

        assertionId = assertDataFor(
            activeAssertion.dataId,
            activeAssertion.data,
            activeAssertion.asserter
        );
        assertionConfig[assertionId] = RewardRoundConfiguration(
            block.timestamp,
            activeTargetValue,
            activeKPI,
            false
        );
    }

    // Owner functions:

    function createKPI(
        bool _continuous,
        uint[] calldata _trancheValues,
        uint[] calldata _trancheRewards
    ) external onlyOrchestratorOwner {
        // TODO sets the KPI that will be used to calculate the reward
        // Should it be only the owner, or do we create a separate role for this? -> owner for now
        // Also should we set more than one KPI in one step? -> nope. Multicall
        uint _numOfTranches = _trancheValues.length;
        
        if (_numOfTranches < 1 || _numOfTranches > 20) {
            revert Module__KPIRewarder__InvalidTrancheNumber();
        }

        if (
            _numOfTranches != _trancheRewards.length
        ) {
            revert Module__KPIRewarder__InvalidKPIValueLengths();
        }

        for (uint i = 0; i < _numOfTranches - 1; i++) {
            if (_trancheValues[i] >= _trancheValues[i + 1]) {
                revert Module__KPIRewarder__InvalidKPIValues();
            }
        }

        registryOfKPIs[KPICounter] = KPI(
            block.timestamp,
            _numOfTranches,
            _continuous,
            _trancheValues,
            _trancheRewards
        );
        KPICounter++;
    }

    function setKPI(uint _KPINumber) external onlyOrchestratorOwner {
        //TODO: Input validation
        activeKPI = _KPINumber;
    }

    /*    
    // Maybe not needed as standalone function, just implement it into the assertionResolvedCallback
    function returnExcessFunds() external onlyOrchestratorOwner {
        // TODO returns the excess funds to the FundingManager
    }
    */
    // StakingManager Overrides:

    /// @inheritdoc IStakingManager
    function stake(uint amount)
        external
        override
        nonReentrant
        validAmount(amount)
    {
        address sender = _msgSender();

        QueuedStake memory newStake =
            QueuedStake({stakerAddress: sender, amount: amount});

        if (stakingQueue.length >= MAX_QUEUE_LENGTH) {
            revert Module__KPIRewarder__StakingQueueIsFull();
        }
        stakingQueue.push(newStake);

        totalQueuedFunds += amount;

        //transfer funds to stakingManager
        IERC20(stakingToken).safeTransferFrom(sender, address(this), amount);

        emit StakeEnqueued(sender, amount);
    }

    // No need to override this
    /*     function unstake(uint amount)
        external
        override
        nonReentrant
        validAmount(amount)
    {
        
    } */

    // Optimistic Oracle Overrides:

    /// @inheritdoc IOptimisticOracleIntegrator
    /// @dev This updates status on local storage (or deletes the assertion if it was deemed false). Any additional functionalities can be appended by the inheriting contract.
    function assertionResolvedCallback(
        bytes32 assertionId,
        bool assertedTruthfully
    ) public override {
        // TODO
        if (assertedTruthfully) {
            // SECURITY NOTE: this will add the value, but provides no guarantee that the fundingmanager actually holds those funds
            //calculate rewardamount from asserionId value
            KPI memory resolvedKPI =
                registryOfKPIs[assertionConfig[assertionId].KpiToUse];
            uint rewardAmount;

            for (uint i; i < resolvedKPI.numOfTranches; i++) {
                if (
                    resolvedKPI.trancheValues[i]
                        <= assertionConfig[assertionId].assertedValue
                ) {
                    //the asserted value is above tranche end
                    rewardAmount += resolvedKPI.trancheRewards[i];
                } else {
                    //tranche was not completed
                    if (resolvedKPI.continuous) {
                        //continuous distribution
                        uint trancheRewardValue = resolvedKPI.trancheRewards[i];
                        uint trancheStart =
                            i == 0 ? 0 : resolvedKPI.trancheValues[i - 1];

                        uint achievedReward = assertionConfig[assertionId]
                            .assertedValue - trancheStart;
                        uint trancheEnd =
                            resolvedKPI.trancheValues[i] - trancheStart;

                        rewardAmount +=
                            achievedReward * (trancheRewardValue / trancheEnd); // since the trancheRewardValue will be a very big number.
                    }
                    //else -> no reward

                    //exit the loop
                    break;
                }
            }

            _setRewards(rewardAmount, 1);
            // emit DataAssertionResolved
        } else {
            // emit assertionReturnedFalse;
        }
    }

    /// @inheritdoc IOptimisticOracleIntegrator
    /// @dev This OptimisticOracleV3 callback function needs to be defined so the OOv3 doesn't revert when it tries to call it.
    function assertionDisputedCallback(bytes32 assertionId) public override {
        //TODO
    }
}
