// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {TransparentUpgradeableProxy} from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ProjectTrackerProxy is TransparentUpgradeableProxy {
    constructor(
        address _implementation,
        address _admin,
        bytes memory _data
    ) TransparentUpgradeableProxy(_implementation, _admin, _data) {}
}
