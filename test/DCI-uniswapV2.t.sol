pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DCI_UniswapV2} from "src/DCI-uniswapV2.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract token0 is ERC20("token0", "tk0") {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract token1 is ERC20("token1", "tk1") {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DCI_UniswapV2Test is Test {
    DCI_UniswapV2 public pairContract;
    token0 public token0Contract;
    token1 public token1Contract;
    address public walletAddress;

    function setUp() public {
        token0Contract = new token0();
        token1Contract = new token1();
        pairContract = new DCI_UniswapV2(token0Contract, token1Contract);
        walletAddress = vm.addr(1);
        vm.label(walletAddress, "walletAddress");
        vm.label(address(pairContract), "pairContract");
        vm.label(address(token0Contract), "token0Contract");
        vm.label(address(token1Contract), "token1Contract");
    }

    function test_mint() public {
        // setup
        uint256 token0amount = 1 ether;
        uint256 token1amount = 4 ether;
        uint256 expectedLiquidity = 2 ether;
        token0Contract.mint(walletAddress, token0amount);
        token1Contract.mint(walletAddress, token1amount);

        // test
        vm.startPrank(walletAddress);
        token0Contract.approve(address(pairContract), token0amount);
        token1Contract.approve(address(pairContract), token1amount);

        vm.expectEmit(address(token0Contract));
        emit IERC20.Transfer(walletAddress, address(pairContract), token0amount);

        vm.expectEmit(address(token1Contract));
        emit IERC20.Transfer(walletAddress, address(pairContract), token1amount);

        vm.expectEmit(address(pairContract));
        emit IERC20.Transfer(address(0), address(0), 10 ** 3);

        vm.expectEmit(address(pairContract));
        emit IERC20.Transfer(address(0), walletAddress, expectedLiquidity - 10 ** 3);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Sync(token0amount, token1amount);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Mint(walletAddress, token0amount, token1amount, expectedLiquidity - 10 ** 3);

        (uint256 amount0, uint256 amount1, uint256 liquidity) =
            pairContract.mint(token0amount, token1amount, 8e17, 32e17);

        assertEq(pairContract.totalSupply(), expectedLiquidity);
        assertEq(pairContract.balanceOf(walletAddress), expectedLiquidity - 10 ** 3);
        assertEq(token0Contract.balanceOf(address(pairContract)), amount0);
        assertEq(token1Contract.balanceOf(address(pairContract)), amount1);
        (uint256 _reserve0, uint256 _reserve1) = pairContract.getReserves();
        assertEq(_reserve0, amount0);
        assertEq(_reserve1, amount1);
    }

    function test_burn() public {
        // setup
        uint256 token0amount = 3 ether;
        uint256 token1amount = 3 ether;
        token0Contract.mint(walletAddress, token0amount);
        token1Contract.mint(walletAddress, token1amount);
        vm.startPrank(walletAddress);
        token0Contract.approve(address(pairContract), token0amount);
        token1Contract.approve(address(pairContract), token1amount);
        (uint256 amount0, uint256 amount1, uint256 liquidity) =
            pairContract.mint(token0amount, token1amount, 28e17, 28e17);

        // test
        vm.expectEmit(address(pairContract));
        emit IERC20.Transfer(walletAddress, address(0), liquidity);

        vm.expectEmit(address(token0Contract));
        emit IERC20.Transfer(address(pairContract), walletAddress, amount0 - 1000);

        vm.expectEmit(address(token1Contract));
        emit IERC20.Transfer(address(pairContract), walletAddress, amount1 - 1000);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Sync(1000, 1000);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Burn(walletAddress, liquidity, amount0 - 1000, amount1 - 1000);

        (uint256 amount0returned, uint256 amount1returned) =
            pairContract.burn(liquidity, amount0 - 10001, amount1 - 10001);

        assertEq(pairContract.totalSupply(), 1000);
        assertEq(token0Contract.balanceOf(address(pairContract)), 1000);
        assertEq(token1Contract.balanceOf(address(pairContract)), 1000);
        uint256 _ts0 = token0Contract.totalSupply();
        assertEq(token0Contract.balanceOf(walletAddress), _ts0 - 1000);
        uint256 _ts1 = token1Contract.totalSupply();
        assertEq(token0Contract.balanceOf(walletAddress), _ts1 - 1000);
    }

    function test_swapExactToken0ForToken1() public {
        // setup
        uint256 token0amount = 5 ether;
        uint256 token1amount = 10 ether;
        uint256 swapAmount = 1 ether;
        uint256 expectedOutputAmount = 1666666666666666667;
        token0Contract.mint(walletAddress, token0amount + swapAmount);
        token1Contract.mint(walletAddress, token1amount);
        vm.startPrank(walletAddress);
        token0Contract.approve(address(pairContract), token0amount + swapAmount);
        token1Contract.approve(address(pairContract), token1amount);
        (uint256 amount0, uint256 amount1, uint256 liquidity) =
            pairContract.mint(token0amount, token1amount, 48e17, 98e17);
        uint256 deadline = vm.getBlockTimestamp() + 1;

        // test
        vm.expectEmit(address(token0Contract));
        emit IERC20.Transfer(walletAddress, address(pairContract), swapAmount);

        vm.expectEmit(address(token1Contract));
        emit IERC20.Transfer(address(pairContract), walletAddress, expectedOutputAmount);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Sync(token0amount + swapAmount, token1amount - expectedOutputAmount);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Swap(walletAddress, swapAmount, 0, 0, expectedOutputAmount);

        uint256 amount1Out = pairContract.swapExactToken0ForToken1(swapAmount, 16e17, deadline);
        (uint256 _reserve0, uint256 _reserve1) = pairContract.getReserves();
        assertEq(_reserve0, token0amount + swapAmount);
        assertEq(_reserve1, token1amount - expectedOutputAmount);
        assertEq(token0Contract.balanceOf(address(pairContract)), token0amount + swapAmount);
        assertEq(token1Contract.balanceOf(address(pairContract)), token1amount - expectedOutputAmount);
        uint256 totalSupplyToken0 = token0Contract.totalSupply();
        uint256 totalSupplyToken1 = token1Contract.totalSupply();
        assertEq(token0Contract.balanceOf(walletAddress), totalSupplyToken0 - token0amount - swapAmount);
        assertEq(token1Contract.balanceOf(walletAddress), totalSupplyToken1 - token1amount + expectedOutputAmount);
    }

    function test_swapToken0forExactToken1() public {
        // setup
        uint256 token0amount = 5 ether;
        uint256 token1amount = 10 ether;
        uint256 swapAmount = 1 ether;
        uint256 expectedOutputAmount = 1666666666666666667;
        token0Contract.mint(walletAddress, token0amount + swapAmount);
        token1Contract.mint(walletAddress, token1amount);
        vm.startPrank(walletAddress);
        token0Contract.approve(address(pairContract), token0amount + swapAmount);
        token1Contract.approve(address(pairContract), token1amount);
        (uint256 amount0, uint256 amount1, uint256 liquidity) =
            pairContract.mint(token0amount, token1amount, 48e17, 98e17);
        uint256 deadline = vm.getBlockTimestamp() + 1;

        // test
        vm.expectEmit(address(token0Contract));
        emit IERC20.Transfer(walletAddress, address(pairContract), swapAmount);

        vm.expectEmit(address(token1Contract));
        emit IERC20.Transfer(address(pairContract), walletAddress, expectedOutputAmount);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Sync(token0amount + swapAmount, token1amount - expectedOutputAmount);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Swap(walletAddress, swapAmount, 0, 0, expectedOutputAmount);

        uint256 amount0In = pairContract.swapToken0forExactToken1(expectedOutputAmount, swapAmount + 3e17, deadline);
        (uint256 _reserve0, uint256 _reserve1) = pairContract.getReserves();
        assertEq(_reserve0, token0amount + swapAmount);
        assertEq(_reserve1, token1amount - expectedOutputAmount);
        assertEq(token0Contract.balanceOf(address(pairContract)), token0amount + swapAmount);
        assertEq(token1Contract.balanceOf(address(pairContract)), token1amount - expectedOutputAmount);
        uint256 totalSupplyToken0 = token0Contract.totalSupply();
        uint256 totalSupplyToken1 = token1Contract.totalSupply();
        assertEq(token0Contract.balanceOf(walletAddress), totalSupplyToken0 - token0amount - swapAmount);
        assertEq(token1Contract.balanceOf(walletAddress), totalSupplyToken1 - token1amount + expectedOutputAmount);
    }

    function test_swapExactToken1forToken0() public {
        // setup
        uint256 token0amount = 5 ether;
        uint256 token1amount = 10 ether;
        uint256 swapAmount = 1666666666666666667;
        uint256 expectedOutputAmount = 1 ether;
        token0Contract.mint(walletAddress, token0amount);
        token1Contract.mint(walletAddress, token1amount + swapAmount);
        vm.startPrank(walletAddress);
        token0Contract.approve(address(pairContract), token0amount);
        token1Contract.approve(address(pairContract), token1amount + swapAmount);
        (uint256 amount0, uint256 amount1, uint256 liquidity) =
            pairContract.mint(token0amount, token1amount, 48e17, 98e17);
        uint256 deadline = vm.getBlockTimestamp() + 1;

        // test
        vm.expectEmit(address(token1Contract));
        emit IERC20.Transfer(walletAddress, address(pairContract), swapAmount);

        vm.expectEmit(address(token0Contract));
        emit IERC20.Transfer(address(pairContract), walletAddress, expectedOutputAmount);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Sync(token0amount - expectedOutputAmount, token1amount + swapAmount);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Swap(walletAddress, 0, swapAmount, expectedOutputAmount, 0);

        uint256 amount0Out = pairContract.swapExactToken1forToken0(swapAmount, 4e17, deadline);
        (uint256 _reserve0, uint256 _reserve1) = pairContract.getReserves();
        assertEq(_reserve0, token0amount - expectedOutputAmount);
        assertEq(_reserve1, token1amount + swapAmount);
        assertEq(token0Contract.balanceOf(address(pairContract)), token0amount - expectedOutputAmount);
        assertEq(token1Contract.balanceOf(address(pairContract)), token1amount + swapAmount);
        uint256 totalSupplyToken0 = token0Contract.totalSupply();
        uint256 totalSupplyToken1 = token1Contract.totalSupply();
        assertEq(token0Contract.balanceOf(walletAddress), totalSupplyToken0 - token0amount + expectedOutputAmount);
        assertEq(token1Contract.balanceOf(walletAddress), totalSupplyToken1 - token1amount - swapAmount);
    }

    function test_swapToken1forExactToken0() public {
        // setup
        uint256 token0amount = 5 ether;
        uint256 token1amount = 10 ether;
        uint256 swapAmount = 1000000000000000001;
        uint256 expectedOutputAmount = 454545454545454546;
        token0Contract.mint(walletAddress, token0amount);
        token1Contract.mint(walletAddress, token1amount + swapAmount);
        vm.startPrank(walletAddress);
        token0Contract.approve(address(pairContract), token0amount);
        token1Contract.approve(address(pairContract), token1amount + swapAmount);
        (uint256 amount0, uint256 amount1, uint256 liquidity) =
            pairContract.mint(token0amount, token1amount, 48e17, 98e17);
        uint256 deadline = vm.getBlockTimestamp() + 1;

        // test
        vm.expectEmit(address(token1Contract));
        emit IERC20.Transfer(walletAddress, address(pairContract), swapAmount);

        vm.expectEmit(address(token0Contract));
        emit IERC20.Transfer(address(pairContract), walletAddress, expectedOutputAmount);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Sync(token0amount - expectedOutputAmount, token1amount + swapAmount);

        vm.expectEmit(address(pairContract));
        emit DCI_UniswapV2.Swap(walletAddress, 0, swapAmount, expectedOutputAmount, 0);

        uint256 amount1In = pairContract.swapToken1forExactToken0(expectedOutputAmount, swapAmount + 2e18, deadline);
        (uint256 _reserve0, uint256 _reserve1) = pairContract.getReserves();
        assertEq(_reserve0, token0amount - expectedOutputAmount);
        assertEq(_reserve1, token1amount + swapAmount);
        assertEq(token0Contract.balanceOf(address(pairContract)), token0amount - expectedOutputAmount);
        assertEq(token1Contract.balanceOf(address(pairContract)), token1amount + swapAmount);
        uint256 totalSupplyToken0 = token0Contract.totalSupply();
        uint256 totalSupplyToken1 = token1Contract.totalSupply();
        assertEq(token0Contract.balanceOf(walletAddress), totalSupplyToken0 - token0amount + expectedOutputAmount);
        assertEq(token1Contract.balanceOf(walletAddress), totalSupplyToken1 - token1amount - swapAmount);
    }
}
