// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import {ICurveGauge, ICurveMinter, IERC20} from "../interface/ICurve.sol";

contract MockMinter is ICurveMinter {
    IERC20 crvToken;

    constructor(IERC20 _crvToken) public {
        crvToken = _crvToken;
    }

    function mint(address gauge) external override {}

    function token() external override view returns (IERC20) {
        return crvToken;
    }
}

contract MockCurveGauge is ICurveGauge {
    ICurveMinter _minter;

    constructor(IERC20 crvToken) public {
        _minter = new MockMinter(crvToken);
    }

    function balanceOf(address depositor) external override view returns (uint256) {
        return 0;
    }

    function minter() external override returns (ICurveMinter) {
        return _minter;
    }

    function deposit(uint256 amount) external override {}

    function withdraw(uint256 amount) external override {}
}
