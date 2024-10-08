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

    function test_swap() public {
        //
    }
}
