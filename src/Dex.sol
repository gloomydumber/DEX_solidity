// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/console.sol";

contract Dex is ERC20 {
    address public tokenX;
    address public tokenY;

    uint112 private reserveX;
    uint112 private reserveY;

    constructor(address _tokenX, address _tokenY) ERC20("Upside Liquidity Token", "ULT") {
        tokenX = _tokenX;
        tokenY = _tokenY;
    }

    function swap(uint256 amountXout, uint256 amountYout, uint256 minimum) external returns (uint256 realAmountOut) {
        require((amountXout == 0 && amountYout != 0) || (amountXout != 0 && amountYout == 0), "INVALID_OUTPUT_AMOUNT");

        (uint112 _reserveX, uint112 _reserveY) = getReserves();
        require(amountXout < _reserveX && amountYout < _reserveY, "INSUFFICIENT_LIQUIDITY");

        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));

        uint256 amountXin = balanceX > _reserveX - amountXout ? balanceX - (_reserveX - amountXout) : 0;
        uint256 amountYin = balanceY > _reserveY - amountYout ? balanceY - (_reserveY - amountYout) : 0;

        uint256 amountInWithFee;
        uint256 numerator;
        uint256 denominator;

        if (amountXin > 0) {
            IERC20(tokenX).transferFrom(msg.sender, address(this), amountXin);

            amountInWithFee = amountXin * 999; // 0.1% fee
            numerator = amountInWithFee * _reserveY;
            denominator = (_reserveX * 1000) + amountInWithFee;
            realAmountOut = numerator / denominator;

            require(realAmountOut >= minimum, "INSUFFICIENT_OUTPUT_AMOUNT");
            safeTransfer(tokenY, msg.sender, realAmountOut);
        } else if (amountYin > 0) {
            IERC20(tokenY).transferFrom(msg.sender, address(this), amountYin);

            amountInWithFee = amountYin * 999; // 0.1% fee
            numerator = amountInWithFee * _reserveX;
            denominator = (_reserveY * 1000) + amountInWithFee;
            realAmountOut = numerator / denominator;

            require(realAmountOut >= minimum, "INSUFFICIENT_OUTPUT_AMOUNT");
            safeTransfer(tokenX, msg.sender, realAmountOut);
        }

        balanceX = IERC20(tokenX).balanceOf(address(this));
        balanceY = IERC20(tokenY).balanceOf(address(this));
        update(balanceX, balanceY);

        return realAmountOut;
    }

    function addLiquidity(uint256 _amountX, uint256 _amountY, uint256 _minLP) external returns (uint256) {
        require(IERC20(tokenX).allowance(msg.sender, address(this)) >= _amountX, "ERC20: insufficient allowance");
        require(IERC20(tokenY).allowance(msg.sender, address(this)) >= _amountY, "ERC20: insufficient allowance");
        require(IERC20(tokenX).balanceOf(msg.sender) >= _amountX, "ERC20: transfer amount exceeds balance");
        require(IERC20(tokenY).balanceOf(msg.sender) >= _amountY, "ERC20: transfer amount exceeds balance");

        IERC20(tokenX).transferFrom(msg.sender, address(this), _amountX);
        IERC20(tokenY).transferFrom(msg.sender, address(this), _amountY);

        uint256 liquidity = this.mint(msg.sender);

        require(liquidity >= _minLP, "INSUFFICIENT_LIQUIDITY_MINTED");

        return liquidity;
    }

    function removeLiquidity(uint256 _amount, uint256 _minimumX, uint256 _minimumY)
        external
        returns (uint256, uint256)
    {
        transferFrom(msg.sender, address(this), _amount);

        (uint256 amountX, uint256 amountY) = this.burn(_amount);

        require(amountX >= _minimumX, "INSUFFICIENT_X_RECEIVED");
        require(amountY >= _minimumY, "INSUFFICIENT_Y_RECEIVED");

        return (amountX, amountY);
    }

    function mint(address _to) external returns (uint256 liquidity) {
        (uint112 _reserveX, uint112 _reserveY) = getReserves();
        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));
        uint256 amountX = balanceX - _reserveX;
        uint256 amountY = balanceY - _reserveY;
        uint256 totalSupply = totalSupply();

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amountX * amountY);
        } else {
            liquidity = Math.min(amountX * totalSupply / reserveX, amountY * totalSupply / reserveY);
        }

        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        _mint(_to, liquidity);
        update(balanceX, balanceY);
    }

    function burn(uint256 liquidity) external returns (uint256 _amountX, uint256 _amountY) {
        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));
        uint256 totalSupply = totalSupply();

        _amountX = liquidity * balanceX / totalSupply;
        _amountY = liquidity * balanceY / totalSupply;

        require(_amountX > 0 && _amountY > 0, "INSUFFICENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        safeTransfer(tokenX, msg.sender, _amountX);
        safeTransfer(tokenY, msg.sender, _amountY);

        balanceX = IERC20(tokenX).balanceOf(address(this));
        balanceY = IERC20(tokenY).balanceOf(address(this));

        update(balanceX, balanceY);
    }

    function getReserves() public view returns (uint112 _reserveX, uint112 _reserveY) {
        _reserveX = reserveX;
        _reserveY = reserveY;
    }

    function update(uint256 _balanceX, uint256 _balanceY) public {
        require(_balanceX <= type(uint112).max && _balanceY <= type(uint112).max, "OVERFLOW");
        reserveX = uint112(_balanceX);
        reserveY = uint112(_balanceY);
    }

    function safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(bytes4(keccak256(bytes("transfer(address,uint256)"))), to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        address spender = _msgSender();

        if (to == address(this)) {
            _transfer(from, to, value);
        } else {
            _spendAllowance(from, spender, value);
            _transfer(from, to, value);
        }

        return true;
    }
}
