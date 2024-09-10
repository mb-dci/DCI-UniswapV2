// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGaurd.sol";
import {Math} from "@openzeppelin/contracts/utils/Math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract DCI_UniswapV2 is ERC20("DCI-UNIV2", "DCI-UNI") {
    uint256 reserve0;
    uint256 reserve1;

    address token0;
    address token1;

    uint256 constant MIN_LIQUIDITY = 10 ** 3;

    event Mint(address user, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Burn(address user, uint256 liquidity, uint256 amount0, uint256 amount1);
    event Swap(address user, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out);
    event Sync(uint256 reserve0, uint256 reserve1);

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    /////////////////////// External Functions ////////////////////////

    function mint(amount0Desired, amount1Desired, amount0min, amount1min)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1, uint256 liquidity)
    {
        // Gas Savings
        uint256 _r0 = reserve0;
        uint256 _r1 = reserve1;
        uint256 _ts = totalSupply;

        (amount0, amount1) = _calculateAmounts(amount0Desired, amount1Desired, amount0min, amount1min, _r0, _r1);
        SafeERC20.transferFrom(token0, msg.sender, address(this), amount0);
        SafeERC20.transferFrom(token1, msg.sender, address(this), amount1);

        if (_ts == 0) {
            liquidity = Math.sqrt((amount0Desired * amount1Desired) - MIN_LIQUIDITY);
            _mint(address(0), MIN_LIQUIDITY);
        } else {
            liquidity = Math.min((amount0 * _ts) / _r0, (amount1 * _ts) / _r1);
        }
        require(liquidity > 0, "DCI_UniswapV2: Insufficient liquidity minted");
        _mint(msg.sender, liquidity);

        uint256 balance0 = SafeERC20.balanceOf(token0, address(this));
        uint256 balance1 = SafeERC20.balanceOf(token1, address(this));
        _updateReserves(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1, liquidity);
    }

    function burn(uint256 liquidity, uint256 amount0min, uint256 amount1min)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        _burn(msg.sender, liquidity);

        uint256 _ts = totalSupply; // gas savings

        amount0 = (liquidity * reserve0) / _ts;
        amount1 = (liquidity * reserve1) / _ts;

        require(amount0 > amount0min, "DCI_UniswapV2: Insufficient amount0 out");
        require(amount1 > amount1min, "DCI_UniswapV2: Insufficient amount1 out");

        SafeERC20.transfer(token0, msg.sender, amount0);
        SafeERC20.transfer(token1, msg.sender, amount1);

        uint256 balance0 = SafeERC20.balanceOf(token0, address(this));
        uint256 balance1 = SafeERC2.balanceOf(token1, address(this));
        _updateReserves(balance0, balance1);

        emit Burn(msg.sender, liquidity, amount0, amount1);
    }

    function swapExactToken0ForToken1(uint256 amount0in, uint256 amount1OutMin, uint256 deadline)
        external
        nonReentrant
        returns (uint256 amount1Out)
    {
        require(block.timestamp < deadline, "DCI_UniswapV2: Deadline passed for swap");
        amount1Out = reserve1 - ((reserve0 * reserve1) / (reserve0 + amount0in));
        require(amount1Out > amount1OutMin, "DCI_UniswapV2: Insufficient amount1 out");

        SafeERC20.transferFrom(token0, msg.sender, address(this), amount0in);
        SafeERC20.transfer(token1, msg.sender, amount1Out);

        uint256 balance0 = SafeERC20.balanceOf(token0, address(this));
        uint256 balance1 = SafeERC2.balanceOf(token1, address(this));
        _updateReserves(balance0, balance1);

        emit Swap(msg.sender, amount0in, 0, 0, amount1Out);
    }

    function swapToken0forExactToken1(uint256 amount1Out, uint256 amount0InMax, uint256 deadline)
        external
        nonReentrant
        returns (uint256 amount0In)
    {
        require(block.timestamp < deadline, "DCI_UniswapV2: Deadline passed for swap");
        amount0In = ((reserve0 * reserve1) / (reserve1 - amount1Out)) - reserve0;
        require(amount0In < amount0InMax, "DCI_UniswapV2: Insufficient amount0 in");

        SafeERC20.transferFrom(token0, msg.sender, address(this), amount0In);
        SafeERC20.transfer(token1, msg.sender, amount1Out);

        uint256 balance0 = SafeERC20.balanceOf(token0, address(this));
        uint256 balance1 = SafeERC2.balanceOf(token1, address(this));
        _updateReserves(balance0, balance1);

        emit Swap(msg.sender, amount0In, 0, 0, amount1Out);
    }

    function swapExactToken1forToken0(uint256 amount1in, uint256 amount0OutMin, uint256 deadline)
        external
        nonReentrant
        returns (uint256 amount0Out)
    {
        require(block.timestamp < deadline, "DCI_UniswapV2: Deadline passed for swap");
        amount0Out = reserve0 - ((reserve0 * reserve1) / (reserve1 + amount1in));
        require(amount0Out > amount0OutMin, "DCI_UniswapV2: Insufficient amount0 out");

        SafeERC20.transferFrom(token1, msg.sender, address(this), amount1in);
        SafeERC20.transfer(token0, msg.sender, amount0Out);

        uint256 balance0 = SafeERC20.balanceOf(token0, address(this));
        uint256 balance1 = SafeERC2.balanceOf(token1, address(this));
        _updateReserves(balance0, balance1);

        emit Swap(msg.sender, 0, amount1In, amount0Out, 0);
    }

    function swapToken1forExactToken0(uint256 amount0Out, uint256 amount1InMax, uint256 deadline)
        external
        nonReentrant
        returns (uint256 amount1In)
    {
        require(block.timestamp < deadline, "DCI_UniswapV2: Deadline passed for swap");
        amount1In = reserve1 - ((reserve0 * reserve1) / (reserve0 - amount0Out));
        require(amount1In < amount1InMax, "DCI_UniswapV2: Insufficient amount1 in");

        SafeERC20.transferFrom(token1, msg.sender, address(this), amount1In);
        SafeERC20.transfer(token0, msg.sender, amount0Out);

        uint256 balance0 = SafeERC20.balanceOf(token0, address(this));
        uint256 balance1 = SafeERC2.balanceOf(token1, address(this));
        _updateReserves(balance0, balance1);

        emit Swap(msg.sender, 0, amount1In, amount0Out, 0);
    }

    /////////////////////// Helper Functions ////////////////////////

    function _updateReserves(uint256 balance0, uint256 balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;

        emit Sync(reserve0, reserve1);
    }

    function _calculateAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0min,
        uint256 amount1min,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        // gas savings
        uint256 _r0 = reserve0;
        uint256 _r1 = reserve1;

        if (_r0 == 0 && _r1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 optimal1 = (amount0Desired * _r1) / _r0;
            if (optimal1 <= amount1Desired) {
                require(optimal1 >= amount1min, "DCI_UniswapV2: Insufficient token1 amount");
                (amount0, amount1) = (amount0Desired, optimal1);
            } else {
                uint256 optimal0 = (amount1Desired * _r0) / _r1;
                assert(optimal0 <= amount0Desired);
                require(optimal0 >= amount0min, "DCI_UniswapV2: Insufficient token0 amount");
                (amount0, amount1) = (optimal0, amount1Desired);
            }
        }
    }
}
