// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Dex.sol";

contract CustomERC20 is ERC20 {
    constructor(string memory tokenName) ERC20(tokenName, tokenName) {
        _mint(msg.sender, type(uint256).max);
    }
}

/*
 * Contract에서 필요한 만큼(또는 요청한 만큼)의 자산을 가져가도록 구현되어있다는 것을 가정하였습니다.
 * (transferFrom을 통해)
 */
contract DexTest is Test {
    Dex public dex;
    ERC20 tokenX;
    ERC20 tokenY;

    function setUp() public {
        tokenX = new CustomERC20("XXX");
        tokenY = new CustomERC20("YYY");

        dex = new Dex(address(tokenX), address(tokenY));

        tokenX.approve(address(dex), type(uint256).max);
        tokenY.approve(address(dex), type(uint256).max);
    }

    function testAddLiquidity1() external {
        uint256 firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint256 secondLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        assertEq(firstLPReturn, secondLPReturn, "AddLiquidity Error 1");
    }

    function testAddLiquidity2() external {
        uint256 firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint256 secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        assertEq(firstLPReturn * 2, secondLPReturn, "AddLiquidity Error 2");
    }

    function testAddLiquidity3() external {
        uint256 firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        (bool success,) = address(dex).call(
            abi.encodeWithSelector(dex.addLiquidity.selector, 1000 ether, 1000 ether, firstLPReturn * 10001 / 10000)
        );
        assertTrue(!success, "AddLiquidity minimum LP return error");
    }

    function testAddLiquidity4() external {
        uint256 firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        (bool success, bytes memory alret) =
            address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 1000 ether, 4000 ether, 0));
        uint256 lpret = uint256(bytes32(alret));
        assertTrue((firstLPReturn == lpret) || !success, "AddLiquidity imbalance add liquidity test error");
    }

    function testAddLiquidity5() external {
        address sender = vm.addr(1);
        tokenX.transfer(sender, 100 ether);
        tokenY.transfer(sender, 100 ether);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.startPrank(sender);
        dex.addLiquidity(1000 ether, 1000 ether, 0);

        tokenX.approve(address(dex), type(uint256).max);
        tokenY.approve(address(dex), type(uint256).max);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        dex.addLiquidity(1000 ether, 1000 ether, 0);

        vm.stopPrank();
    }

    function testAddLiquidity6() external {
        (bool success,) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 0 ether, 0 ether, 0));
        assertTrue(!success, "AddLiquidity invalid initialization check error - 1");
        (success,) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 1 ether, 0 ether, 0));
        assertTrue(!success, "AddLiquidity invalid initialization check error - 2");
        (success,) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 0 ether, 1 ether, 0));
        assertTrue(!success, "AddLiquidity invalid initialization check error - 3");
    }

    function testRemoveLiquidity1() external {
        uint256 firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint256 secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        (uint256 tx, uint256 ty) = dex.removeLiquidity(secondLPReturn, 0, 0);
        assertEq(tx, 1000 ether * 2, "RemoveLiquiidty tx error");
        assertEq(ty, 1000 ether * 2, "RemoveLiquiidty tx error");
    }

    function testRemoveLiquidity2() external {
        uint256 firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint256 secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        (bool success,) = address(dex).call(
            abi.encodeWithSelector(dex.removeLiquidity.selector, secondLPReturn, 2001 ether, 2001 ether)
        );
        assertTrue(!success, "RemoveLiquidity minimum return error");
    }

    function testRemoveLiquidity3() external {
        uint256 firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint256 secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        (bool success,) = address(dex).call(abi.encodeWithSelector(dex.removeLiquidity.selector, secondLPReturn * 2));
        assertTrue(!success, "RemoveLiquidity exceeds balance check error");
    }

    function testRemoveLiquidity4() external {
        uint256 firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint256 secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        uint256 sumX;
        uint256 sumY;
        for (uint256 i = 0; i < 100; i++) {
            sumX += dex.swap(0, 1000 ether, 0);
            sumY += dex.swap(1000 ether, 0, 0);
        }

        // usedX = 1000 ether * 100
        // usedY = 1000 ether * 100

        uint256 poolAmountX = 1000 ether + 1000 ether * 2; // initial value
        poolAmountX += 1000 ether * 100;
        uint256 poolAmountY = 1000 ether + 1000 ether * 2; // initial value
        poolAmountY += 1000 ether * 100;

        poolAmountX -= sumX;
        poolAmountY -= sumY;

        emit log_named_uint("remaining poolAmountX", poolAmountX);
        emit log_named_uint("remaining poolAmountY", poolAmountY);

        (uint256 rx, uint256 ry) = dex.removeLiquidity(firstLPReturn, 0, 0);

        bool successX = rx <= (poolAmountX * 10001 / 10000 / 3) && rx >= (poolAmountX * 9999 / 10000 / 3); // allow 0.01%;
        bool successY = ry <= (poolAmountY * 10001 / 10000 / 3) && ry >= (poolAmountY * 9999 / 10000 / 3); // allow 0.01%;
        assertTrue(successX, "remove liquidity after swap error; rx");
        assertTrue(successY, "remove liquidity after swap error; ry");
    }

    function testSwap1() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // x -> y
        uint256 output = dex.swap(300 ether, 0, 0);

        uint256 poolAmountX = 60000 ether + 3000 ether;
        uint256 poolAmountY = 80000 ether + 4000 ether;

        int256 expectedOutput =
            -(int256(poolAmountX * poolAmountY) / int256(poolAmountX + 300 ether)) + int256(poolAmountY);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint256 uExpectedOutput = uint256(expectedOutput);

        emit log_named_int("expected output", expectedOutput);
        emit log_named_uint("real output", output);

        bool success = output <= (uExpectedOutput * 10001 / 10000) && output >= (uExpectedOutput * 9999 / 10000); // allow 0.01%;
        assertTrue(success, "Swap test fail 1; expected != return");
    }

    function testSwap2() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        uint256 output = dex.swap(0, 6000 ether, 0);

        uint256 poolAmountX = 60000 ether + 3000 ether;
        uint256 poolAmountY = 80000 ether + 4000 ether;

        int256 expectedOutput =
            -(int256(poolAmountY * poolAmountX) / int256(poolAmountY + 6000 ether)) + int256(poolAmountX);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint256 uExpectedOutput = uint256(expectedOutput);

        emit log_named_int("expected output", expectedOutput);
        emit log_named_uint("real output", output);

        bool success = output <= (uExpectedOutput * 10001 / 10000) && output >= (uExpectedOutput * 9999 / 10000); // allow 0.01%;
        assertTrue(success, "Swap test fail 2; expected != return");
    }

    function testSwap3() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        // check invalid swap
        (bool success,) = address(dex).call(abi.encodeWithSelector(dex.swap.selector, 1, 6000 ether, 0));
        assertTrue(!success, "Swap test fail 3; invalid input test failed");
    }

    function testSwap4() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        uint256 poolAmountX = 60000 ether + 3000 ether;
        uint256 poolAmountY = 80000 ether + 4000 ether;

        int256 expectedOutput =
            -(int256(poolAmountY * poolAmountX) / int256(poolAmountY + 6000 ether)) + int256(poolAmountX);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint256 uExpectedOutput = uint256(expectedOutput);

        emit log_named_int("expected output", expectedOutput);

        (bool success,) =
            address(dex).call(abi.encodeWithSelector(dex.swap.selector, 0, 6000 ether, uExpectedOutput * 1005 / 1000));
        assertTrue(!success, "Swap test fail 4; minimum ouput amount check failed");
    }

    function testAddLiquidity7() external {
        tokenX.transfer(address(dex), 1000 ether);
        uint256 lp = dex.addLiquidity(3000 ether, 4000 ether, 0);
        emit log_named_uint("LP", lp);

        tokenX.transfer(address(dex), 1000 ether);
        uint256 lp2 = dex.addLiquidity(5000 ether, 4000 ether, 0);
        emit log_named_uint("LP", lp);

        (uint256 rx, uint256 ry) = dex.removeLiquidity(lp, 0, 0);
        assertEq(rx, 5000 ether, "rx failed");
        assertEq(ry, 4000 ether, "ry failed");
    }
}
