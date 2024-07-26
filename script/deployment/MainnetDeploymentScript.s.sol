// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ModuleRegistry} from "script/ModuleRegistry.sol";

// Import interfaces:

import {IModule_v1} from "src/modules/base/IModule_v1.sol";
import {ModuleFactory_v1} from "src/factories/ModuleFactory_v1.sol";
import {OrchestratorFactory_v1} from "src/factories/OrchestratorFactory_v1.sol";
import {IInverterBeacon_v1} from "src/proxies/interfaces/IInverterBeacon_v1.sol";

import {Governor_v1} from "@ex/governance/Governor_v1.sol";
import {FeeManager_v1} from "@ex/fees/FeeManager_v1.sol";

// Import scripts:
import {DeployAndSetUpInverterBeacon_v1} from
    "script/proxies/DeployAndSetUpInverterBeacon_v1.s.sol";

contract MainnetDeploymentScript is ModuleRegistry {
    error BeaconProxyDeploymentFailed();

    // ------------------------------------------------------------------------

    // Beacon Deployment Script
    DeployAndSetUpInverterBeacon_v1 deployAndSetupInverterBeacon_v1 =
        new DeployAndSetUpInverterBeacon_v1();

    // TransactionForwarder_v1
    address forwarder_Proxy;
    address forwarder_Beacon;

    address governor_Beacon;
    address governor_Proxy;

    address feeManager_Beacon;
    address feeManager_Proxy;

    address orchestratorFactory_Beacon;
    address orchestratorFactory_Proxy;

    address moduleFactory_Beacon;
    address moduleFactory_Proxy;

    IModule_v1.Metadata[] initialMetadataRegistration;
    IInverterBeacon_v1[] initialBeaconRegistration;

    bytes buf_constructorArgs;

    /// @notice Deploys all necessary factories, beacons and implementations
    /// @return factory The addresses of the fully deployed orchestrator factory. All other addresses should be accessible from this.
    function run() public virtual returns (address factory) {
        // TODO: Salted deployments! Check where the commit is and add it.

        // TODO: Make logs pretty

        console2.log(
            "-----------------------------------------------------------------------------"
        );
        console2.log("Deploy reverter\n");
        // Reverter
        reverter_Implementation =
            deployImplementation("InverterReverter_v1", bytes(""));

        console2.log(
            "-----------------------------------------------------------------------------"
        );

        console2.log("Deploy Fee Manager \n");

        feeManager_Implementation =
            deployImplementation("FeeManager_v1", bytes(""));

        (feeManager_Beacon, feeManager_Proxy) = deployAndSetupInverterBeacon_v1
            .deployBeaconAndSetupProxy(
            feeManager_Metadata.title,
            reverter_Implementation,
            communityMultisig,
            feeManager_Implementation,
            feeManager_Metadata.majorVersion,
            feeManager_Metadata.minorVersion,
            feeManager_Metadata.patchVersion
        );

        console2.log(
            "-----------------------------------------------------------------------------"
        );
        console2.log("Governance Contract \n");

        governor_Implementation = deployImplementation("Governor_v1", bytes(""));

        (governor_Beacon, governor_Proxy) = deployAndSetupInverterBeacon_v1
            .deployBeaconAndSetupProxy(
            governor_Metadata.title,
            reverter_Implementation,
            communityMultisig,
            governor_Implementation,
            governor_Metadata.majorVersion,
            governor_Metadata.minorVersion,
            governor_Metadata.patchVersion
        );

        console2.log(
            "-----------------------------------------------------------------------------"
        );

        console2.log("Deploy forwarder implementation and proxy \n");
        // Deploy TransactionForwarder_v1 implementation
        buf_constructorArgs = abi.encode("Inverter Transaction Forwarder");
        forwarder_Implementation =
            deployImplementation("TransactionForwarder_v1", buf_constructorArgs);

        // Deploy beacon and actual proxy
        (forwarder_Beacon, forwarder_Proxy) = deployAndSetupInverterBeacon_v1
            .deployBeaconAndSetupProxy(
            forwarder_Metadata.title,
            reverter_Implementation,
            address(governor_Proxy),
            forwarder_Implementation,
            forwarder_Metadata.majorVersion,
            forwarder_Metadata.minorVersion,
            forwarder_Metadata.patchVersion
        );

        if (
            forwarder_Proxy == forwarder_Implementation
                || forwarder_Proxy == forwarder_Beacon
        ) {
            revert BeaconProxyDeploymentFailed();
        }

        console2.log(
            "-----------------------------------------------------------------------------"
        );

        console2.log("Deploy orchestrator implementation \n");
        // Orchestrator_v1
        buf_constructorArgs = abi.encode(forwarder_Proxy);
        orchestrator_Implementation = deployImplementation(
            orchestrator_Metadata.title, buf_constructorArgs
        );

        address orchestratorImplementationBeacon =
        deployAndSetupInverterBeacon_v1.deployInverterBeacon(
            orchestrator_Metadata.title,
            reverter_Implementation,
            address(governor_Proxy),
            orchestrator_Implementation,
            orchestrator_Metadata.majorVersion,
            orchestrator_Metadata.minorVersion,
            orchestrator_Metadata.patchVersion
        );

        console2.log(
            "-----------------------------------------------------------------------------"
        );

        // =============================================================================
        // Deploy Orchestrator and Module Factory implementations and beacons
        // =============================================================================

        console2.log(
            "-----------------------------------------------------------------------------"
        );
        console2.log(
            "Deploy orchestrator and module factory implementations and beacons \n"
        );

        // Deploy orchestratorFactory
        console2.log("Deploy orchestratorFactory implementation and proxy \n");
        // Deploy TransactionForwarder_v1 implementation
        buf_constructorArgs = abi.encode(forwarder_Proxy);
        orchestratorFactory_Implementation = deployImplementation(
            orchestratorFactory_Metadata.title, buf_constructorArgs
        );

        (orchestratorFactory_Beacon, orchestratorFactory_Proxy) =
        deployAndSetupInverterBeacon_v1.deployBeaconAndSetupProxy(
            orchestratorFactory_Metadata.title,
            reverter_Implementation,
            address(governor_Proxy),
            orchestratorFactory_Implementation,
            orchestratorFactory_Metadata.majorVersion,
            orchestratorFactory_Metadata.minorVersion,
            orchestratorFactory_Metadata.patchVersion
        );

        // Deploy moduleFactory
        buf_constructorArgs =
            abi.encode(reverter_Implementation, forwarder_Proxy);
        moduleFactory_Implementation = deployImplementation(
            moduleFactory_Metadata.title, buf_constructorArgs
        );

        (moduleFactory_Beacon, moduleFactory_Proxy) =
        deployAndSetupInverterBeacon_v1.deployBeaconAndSetupProxy(
            moduleFactory_Metadata.title,
            reverter_Implementation,
            address(governor_Proxy),
            moduleFactory_Implementation,
            moduleFactory_Metadata.majorVersion,
            moduleFactory_Metadata.minorVersion,
            moduleFactory_Metadata.patchVersion
        );

        // =============================================================================
        // Deploy Module Implementations, Beacons and prepare their metadata registration
        // =============================================================================

        console2.log(
            "-----------------------------------------------------------------------------"
        );
        console2.log(
            "Deploy module implementations, beacons and register in module factory v1 \n"
        );

        // Deploy Modules and fill the intitial init list

        // Funding Manager

        _setup_FundingManagers();

        // Authorizer

        _setup_Authorizers();

        // Payment Processor

        _setup_PaymentProcessors();

        // Logic Module

        _setup_LogicModules();

        // =============================================================================
        // Initialize Protocol Singleton Proxies
        // =============================================================================

        // initialize feeManager
        console2.log("Init Fee Manager \n");

        // TODO: use script constants
        vm.startBroadcast(deployerPrivateKey);
        {
            FeeManager_v1(feeManager_Proxy).init(
                address(governor_Proxy),
                treasury, // treasury
                100, // Collateral Fee 1%
                100 // Issuance Fee 1%
            );
        }
        vm.stopBroadcast();

        // intialize Governor
        console2.log("Init Governor \n");

        // TODO: use script constants
        vm.startBroadcast(deployerPrivateKey);
        {
            Governor_v1(governor_Proxy).init(
                communityMultisig,
                teamMultisig,
                1 weeks, //timelockPeriod ,
                feeManager_Proxy
            );
        }
        vm.stopBroadcast();

        // =============================================================================
        // Deploy Factories and register all modules
        // =============================================================================

        console2.log(
            "-----------------------------------------------------------------------------"
        );
        console2.log("Initialze factory implementations \n");

        vm.startBroadcast(deployerPrivateKey);
        {
            OrchestratorFactory_v1(orchestratorFactory_Proxy).init(
                address(governor_Proxy),
                IInverterBeacon_v1(orchestratorImplementationBeacon),
                moduleFactory_Proxy
            );
        }
        vm.stopBroadcast();

        vm.startBroadcast(deployerPrivateKey);
        {
            ModuleFactory_v1(moduleFactory_Proxy).init(
                address(governor_Proxy),
                initialMetadataRegistration,
                initialBeaconRegistration
            );
        }
        vm.stopBroadcast();

        console2.log(
            "-----------------------------------------------------------------------------"
        );

        return (orchestratorFactory_Proxy);
    }

    function _setup_FundingManagers() internal {
        // Rebasing Funding Manager
        FM_Rebasing_v1_Implementation =
            deployImplementation(FM_Rebasing_v1_Metadata.title, bytes(""));
        initialMetadataRegistration.push(FM_Rebasing_v1_Metadata);
        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    FM_Rebasing_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    FM_Rebasing_v1_Implementation,
                    FM_Rebasing_v1_Metadata.majorVersion,
                    FM_Rebasing_v1_Metadata.minorVersion,
                    FM_Rebasing_v1_Metadata.patchVersion
                )
            )
        );

        // Bancor Virtual Supply Bonding Curve Funding Manager
        FM_BC_Bancor_Redeeming_VirtualSupply_v1_Implementation =
        deployImplementation(
            FM_BC_Bancor_Redeeming_VirtualSupply_v1_Metadata.title, bytes("")
        );

        initialMetadataRegistration.push(
            FM_BC_Bancor_Redeeming_VirtualSupply_v1_Metadata
        );

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    FM_BC_Bancor_Redeeming_VirtualSupply_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    FM_BC_Bancor_Redeeming_VirtualSupply_v1_Implementation,
                    FM_BC_Bancor_Redeeming_VirtualSupply_v1_Metadata
                        .majorVersion,
                    FM_BC_Bancor_Redeeming_VirtualSupply_v1_Metadata
                        .minorVersion,
                    FM_BC_Bancor_Redeeming_VirtualSupply_v1_Metadata
                        .patchVersion
                )
            )
        );

        // Restricted Bancor Virtual Supply Bonding Curve Funding Manager
        FM_BC_Restricted_Bancor_Redeeming_VirtualSupply_v1_Implementation =
        deployImplementation(
            FM_BC_Restricted_Bancor_Redeeming_VirtualSupply_v1_Metadata.title,
            bytes("")
        );

        initialMetadataRegistration.push(
            FM_BC_Restricted_Bancor_Redeeming_VirtualSupply_v1_Metadata
        );

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    FM_BC_Restricted_Bancor_Redeeming_VirtualSupply_v1_Metadata
                        .title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    FM_BC_Restricted_Bancor_Redeeming_VirtualSupply_v1_Implementation,
                    FM_BC_Restricted_Bancor_Redeeming_VirtualSupply_v1_Metadata
                        .majorVersion,
                    FM_BC_Restricted_Bancor_Redeeming_VirtualSupply_v1_Metadata
                        .minorVersion,
                    FM_BC_Restricted_Bancor_Redeeming_VirtualSupply_v1_Metadata
                        .patchVersion
                )
            )
        );
    }

    function _setup_Authorizers() internal {
        // RoleAuthorizer
        AUT_Roles_v1_Implementation =
            deployImplementation(AUT_Roles_v1_Metadata.title, bytes(""));

        initialMetadataRegistration.push(AUT_Roles_v1_Metadata);

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    AUT_Roles_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    AUT_Roles_v1_Implementation,
                    AUT_Roles_v1_Metadata.majorVersion,
                    AUT_Roles_v1_Metadata.minorVersion,
                    AUT_Roles_v1_Metadata.patchVersion
                )
            )
        );

        // TokenGated RoleAuthorizer
        AUT_TokenGated_Roles_v1_Implementation = deployImplementation(
            AUT_TokenGated_Roles_v1_Metadata.title, bytes("")
        );

        initialMetadataRegistration.push(AUT_TokenGated_Roles_v1_Metadata);

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    AUT_TokenGated_Roles_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    AUT_TokenGated_Roles_v1_Implementation,
                    AUT_TokenGated_Roles_v1_Metadata.majorVersion,
                    AUT_TokenGated_Roles_v1_Metadata.minorVersion,
                    AUT_TokenGated_Roles_v1_Metadata.patchVersion
                )
            )
        );

        // Single Vote Governor
        AUT_EXT_VotingRoles_v1_Implementation = deployImplementation(
            AUT_EXT_VotingRoles_v1_Metadata.title, bytes("")
        );
        initialMetadataRegistration.push(AUT_EXT_VotingRoles_v1_Metadata);
        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    AUT_EXT_VotingRoles_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    AUT_EXT_VotingRoles_v1_Implementation,
                    AUT_EXT_VotingRoles_v1_Metadata.majorVersion,
                    AUT_EXT_VotingRoles_v1_Metadata.minorVersion,
                    AUT_EXT_VotingRoles_v1_Metadata.patchVersion
                )
            )
        );
    }

    function _setup_PaymentProcessors() internal {
        //  Simple Payment Processor
        PP_Simple_v1_Implementation =
            deployImplementation(PP_Simple_v1_Metadata.title, bytes(""));

        initialMetadataRegistration.push(PP_Simple_v1_Metadata);

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    PP_Simple_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    PP_Simple_v1_Implementation,
                    PP_Simple_v1_Metadata.majorVersion,
                    PP_Simple_v1_Metadata.minorVersion,
                    PP_Simple_v1_Metadata.patchVersion
                )
            )
        );

        //  Streaming Payment Processor
        PP_Streaming_v1_Implementation =
            deployImplementation(PP_Streaming_v1_Metadata.title, bytes(""));

        initialMetadataRegistration.push(PP_Streaming_v1_Metadata);

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    PP_Streaming_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    PP_Streaming_v1_Implementation,
                    PP_Streaming_v1_Metadata.majorVersion,
                    PP_Streaming_v1_Metadata.minorVersion,
                    PP_Streaming_v1_Metadata.patchVersion
                )
            )
        );
    }

    function _setup_LogicModules() internal {
        // Bounty Manager
        LM_PC_Bounties_v1_Implementation =
            deployImplementation(LM_PC_Bounties_v1_Metadata.title, bytes(""));
        initialMetadataRegistration.push(LM_PC_Bounties_v1_Metadata);

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    LM_PC_Bounties_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    LM_PC_Bounties_v1_Implementation,
                    LM_PC_Bounties_v1_Metadata.majorVersion,
                    LM_PC_Bounties_v1_Metadata.minorVersion,
                    LM_PC_Bounties_v1_Metadata.patchVersion
                )
            )
        );

        // Recurring Payment Manager
        LM_PC_RecurringPayments_v1_Implementation = deployImplementation(
            LM_PC_RecurringPayments_v1_Metadata.title, bytes("")
        );

        initialMetadataRegistration.push(LM_PC_RecurringPayments_v1_Metadata);

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    LM_PC_RecurringPayments_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    LM_PC_RecurringPayments_v1_Implementation,
                    LM_PC_RecurringPayments_v1_Metadata.majorVersion,
                    LM_PC_RecurringPayments_v1_Metadata.minorVersion,
                    LM_PC_RecurringPayments_v1_Metadata.patchVersion
                )
            )
        );
        // KPI Rewarder
        LM_PC_KPIRewarder_v1_Implementation =
            deployImplementation(LM_PC_KPIRewarder_v1_Metadata.title, bytes(""));
        initialMetadataRegistration.push(LM_PC_KPIRewarder_v1_Metadata);

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    LM_PC_KPIRewarder_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    LM_PC_KPIRewarder_v1_Implementation,
                    LM_PC_KPIRewarder_v1_Metadata.majorVersion,
                    LM_PC_KPIRewarder_v1_Metadata.minorVersion,
                    LM_PC_KPIRewarder_v1_Metadata.patchVersion
                )
            )
        );

        // Payment Router
        LM_PC_PaymentRouter_v1_Implementation = deployImplementation(
            LM_PC_PaymentRouter_v1_Metadata.title, bytes("")
        );

        initialMetadataRegistration.push(LM_PC_PaymentRouter_v1_Metadata);

        initialBeaconRegistration.push(
            IInverterBeacon_v1(
                deployAndSetupInverterBeacon_v1.deployInverterBeacon(
                    LM_PC_PaymentRouter_v1_Metadata.title,
                    reverter_Implementation,
                    address(governor_Proxy),
                    LM_PC_PaymentRouter_v1_Implementation,
                    LM_PC_PaymentRouter_v1_Metadata.majorVersion,
                    LM_PC_PaymentRouter_v1_Metadata.minorVersion,
                    LM_PC_PaymentRouter_v1_Metadata.patchVersion
                )
            )
        );
    }
}