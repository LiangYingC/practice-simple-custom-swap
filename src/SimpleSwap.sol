// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "./TestERC20.sol";

contract SimpleSwap {
  // phase 1
  TestERC20 public token0;
  TestERC20 public token1;

  // phase 2
  // uint256 public totalSupply = 0;
  // mapping(address => uint256) public share;

  constructor(address _token0, address _token1) {
    // 送進來的是 address，先轉換成 TestERC20 類型後儲存
    token0 = TestERC20(_token0); 
    token1 = TestERC20(_token1);
  }

  // phase 1
  function addLiquidity1(uint256 _amount) public {
    // 從呼叫者（msg.sender）的賬戶中轉移 `_amount` 數量的 `token0`、`token1` 到當前合約地址（SimpleSwap address）
    // 可以說是將 token0, token1 的 SimpleSwap address -> _balance 增加 _amount
    token0.transferFrom(msg.sender, address(this), _amount);
    token1.transferFrom(msg.sender, address(this), _amount);
  }

  function swap(address _tokenIn, uint256 _amountIn) public {
    if (_tokenIn == address(token0)) {
      // 從呼叫者（msg.sender）的賬戶中轉移 ` _amountIn` 數量的 `token0` 到當前合約地址（SimpleSwap address）
      token0.transferFrom(msg.sender, address(this), _amountIn);
      // 當前合約地址（SimpleSwap address）轉給呼叫者（msg.sender）的賬戶 _amountIn 的 token1
      token1.transfer(msg.sender, _amountIn);
    } else if (_tokenIn == address(token1)) {
      token1.transferFrom(msg.sender, address(this), _amountIn);
      token0.transfer(msg.sender, _amountIn);
    }
  }

  function removeLiquidity1() public {
     // 當前合約地址（SimpleSwap address）將所有的 token0、token1 轉回給呼叫者
    token0.transfer(msg.sender, token0.balanceOf(address(this)));
    token1.transfer(msg.sender, token1.balanceOf(address(this)));
  }

  // phase 2
  // function addLiquidity2(uint256 _amount) public {
  // }

  // function removeLiquidity2() public {
  // }
}