// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "./TestERC20.sol";

contract SimpleSwap {
  TestERC20 public token0;
  TestERC20 public token1;

  uint256 public totalSupply = 0;
  mapping(address => uint256) public share;

  constructor(address _token0, address _token1) {
    // 送進來的是 address，先轉換成 TestERC20 類型後儲存
    token0 = TestERC20(_token0); 
    token1 = TestERC20(_token1);
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

  function addLiquidity(uint256 _amount) public {
    token0.transferFrom(msg.sender, address(this), _amount);
    token1.transferFrom(msg.sender, address(this), _amount);
    // 記錄下目前總共的流動性
    totalSupply += _amount;
    // 記錄目前流動性提供者所投入的流動性
    share[msg.sender] += _amount;
  }

  function removeLiquidity() public {
    // 計算出 msg.sender 可以拿出的 token0、token1 數量，需要依據 share/totalSupply 的比例計算。須注意過程中不要有小數計算。
    uint256 token0RemoveAmount = token0.balanceOf(address(this)) * share[msg.sender] / totalSupply;
    uint256 token1RemoveAmount = token1.balanceOf(address(this)) * share[msg.sender] / totalSupply;

    // 當前合約將該轉出的數量轉給 msg.sender
    token0.transfer(msg.sender, token0RemoveAmount);
    token1.transfer(msg.sender, token1RemoveAmount);

    // totalSupply 扣出 msg.sender 取回的部分，並且記得將 msg.sender 的 share 歸零
    totalSupply -= share[msg.sender];
    share[msg.sender] = 0;
  }
}