pragma solidity 0.6.10;

import {ICurveGauge, ICurveMinter} from '../interface/ICurve.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockCurveMinter is ICurveMinter {
    function mint(address gauge) external override {

    }

    function token() external view override returns (IERC20) {
        return IERC20(address(0));
    }
}

contract MockCurveGauge is ICurveGauge {
    function balanceOf(address depositor) external view override returns (uint256) {

    }

    function minter() external override returns (ICurveMinter) {
        return ICurveMinter(address(0));
    }

    function deposit(uint256 amount) external override {

    }

    function withdraw(uint256 amount) external override {

    }
}