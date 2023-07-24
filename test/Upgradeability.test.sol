// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {BaseTest} from "./Base.test.sol";
import {ProjectTracker} from "../src/ProjectTracker.sol";
import {ProjectTrackerProxy} from "../src/proxy/ProjectTrackerProxy.sol";

contract TestUpgradeability is BaseTest {
    ProjectTracker projectTracker;
    ProjectTracker wrappedProxy;
    ProjectTrackerProxy proxy;

    address PROXY_ADMIN = vm.addr(1);
    address IMPLEMENTATION_ADMIN = vm.addr(2);

    function setUp() external {
        // deploy project tracker
        projectTracker = new ProjectTracker();

        // deploy proxy
        proxy = new ProjectTrackerProxy(
            address(projectTracker),
            PROXY_ADMIN,
            ""
        );

        wrappedProxy = ProjectTracker(address(proxy));

        // Initialize the contract
        vm.prank(IMPLEMENTATION_ADMIN);
        wrappedProxy.initialize();
    }

    function testCanInitialize() external {
        assertTrue(
            wrappedProxy.hasRole(
                wrappedProxy.DEFAULT_ADMIN_ROLE(),
                IMPLEMENTATION_ADMIN
            )
        );
    }
}
