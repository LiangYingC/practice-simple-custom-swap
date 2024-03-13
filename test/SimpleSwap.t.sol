// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "../src/TestERC20.sol";
import "../src/SimpleSwap.sol";
import { Test } from "forge-std/Test.sol";

// 定義 SimpleSwapTest contract 並繼承 Test
contract SimpleSwapTest is Test {
  // 定義三個公開的地址變量，用來表示不同的用戶，包含終端使用者(user)、流動性提供者 1(lp1)、流動性提供者 2(lp2)
  address public user = makeAddr("user");
  address public lp1 = makeAddr("lp1");
  address public lp2 = makeAddr("lp2");
  // 定義兩種不同的 token 變量 token0 與 token1
  TestERC20 public token0;
  TestERC20 public token1;
  // 定義 SimpleSwap contract 類型的 simpleSwap
  SimpleSwap public simpleSwap;

  // setUp 函式在每次測試開始前會執行，藉此設置初始狀態
  function setUp() public {
    // 賦予 token0, token1 各別的 ERC20 instance
    token0 = new TestERC20("token 0", "TK0");
    token1 = new TestERC20("token 1", "TK1");

    // 鑄造發放給 user, lp1, lp2 個自 100e18 單位的 token0
    token0.mint(user, 100e18);
    token0.mint(lp1, 100e18);
    token0.mint(lp2, 100e18);
    
    // 鑄造發放給 user, lp1, lp2 個自 100e18 單位的 token1
    token1.mint(user, 100e18);
    token1.mint(lp1, 100e18);
    token1.mint(lp2, 100e18);

    // 賦予 simpleSwap 由 token0, token1 地址 new 出的 SimpleSwap instance
    simpleSwap = new SimpleSwap(address(token0), address(token1));

    // 使用 vm.startPrank(user) 模擬以 user 身份執行後續操作
    vm.startPrank(user);
    // user 地址授權 SimpleSwap 合約從其賬戶中轉出最多 100e18 的 token0、token1
    token0.approve(address(simpleSwap), 100e18);
    token1.approve(address(simpleSwap), 100e18);
    // 使用 vm.stopPrank() 結束模擬，後續操作不再被視為由 user 地址發起
    vm.stopPrank();

    // 以下幾行類似上面的操作，但是換成 lp1 作為操作者
    vm.startPrank(lp1);
    token0.approve(address(simpleSwap), 100e18);
    token1.approve(address(simpleSwap), 100e18);
    vm.stopPrank();

    // 以下幾行類似上面的操作，但是換成 lp2 作為操作者
    vm.startPrank(lp2);
    token0.approve(address(simpleSwap), 100e18);
    token1.approve(address(simpleSwap), 100e18);
    vm.stopPrank();
  }

  ///// Phase 1 /////

  // 測試 addLiquidity1 添加流動性函式的正確情境，預期只有 lp1 參與，因此無需考量 lp1, lp2 添加的佔比問題
  function testAddLiquidity1() public {
    vm.startPrank(lp1);
    // lp1 向 simpleSwap 添加 10e18 token0、token1 的流動性
    simpleSwap.addLiquidity1(10e18);

    // 檢查 lp1 的 token0 和 token1 餘額是否符合預期，斷言剩下 90e18 單位
    assertEq(token0.balanceOf(lp1), 90e18);
    assertEq(token1.balanceOf(lp1), 90e18);

    // 檢查 simpleSwap 的 token0 和 token1 餘額是否符合預期，斷言已有 10e18 單位
    assertEq(token0.balanceOf(address(simpleSwap)), 10e18);
    assertEq(token1.balanceOf(address(simpleSwap)), 10e18);

    vm.stopPrank();
  }

  // 測試 swap 功能函式的正確情境，代幣 1:1 兌換
  function testSwap() public {
    // 先添加流動性才有流動性可以 swap
    testAddLiquidity1();

    vm.startPrank(user);
    // user 使用 5e18 token0 進行交換，兌換 token1
    simpleSwap.swap(address(token0), 5e18);

    // 檢查 user 的 token0 和 token1 餘額是否符合預期
    // token0 減少 5e18; token1 增加 5e18
    assertEq(token0.balanceOf(user), 95e18);
    assertEq(token1.balanceOf(user), 105e18);

    // 檢查 simpleSwap 的 token0 和 token1 餘額是否符合預期
    // token0 增加 5e18; token1 減少 5e18
    assertEq(token0.balanceOf(address(simpleSwap)), 15e18);
    assertEq(token1.balanceOf(address(simpleSwap)), 5e18);

    vm.stopPrank();
  }

  // 測試 removeLiquidity1 移除流動性功能函式的正確情境，預期只有 lp1 參與，因此無需考量 lp1, lp2 添加的佔比問題
  function testRemoveLiquidity1() public {
    // 先觸發 swap 其中會包含
    // (1) 增加流動性 (2) 交換代幣，此時 user 和 simpleSwap 代幣數量是操作後的結果
    testSwap();

    // 模擬 lp1 身份進行移除流動性，亦即把代幣從 simpleSwap 取回
    vm.startPrank(lp1);
    simpleSwap.removeLiquidity1();

    // 檢查 lp1 的 token 餘額
    // 從 simpleSwap 中取出所有 105e18 token0、取出所有 95e18 token1
    assertEq(token0.balanceOf(lp1), 105e18);
    assertEq(token1.balanceOf(lp1), 95e18);

    assertEq(token0.balanceOf(address(simpleSwap)), 0);
    assertEq(token1.balanceOf(address(simpleSwap)), 0);
    vm.stopPrank();
  }

  ///// Phase 2 /////

  // 測試 addLiquidity2 添加流動性函式的正確情境，“需要”考量 lp1, lp2 添加的佔比問題
  function testAddLiquidity2() public {
    // 模擬 lp1 的身份進行操作，替流動池增加 10e18 的流動性
    vm.startPrank(lp1);
    simpleSwap.addLiquidity2(10e18);

    // 檢查 lp1 的 token0 和 token1 餘額是否符合預期，斷言剩下 90e18 單位
    assertEq(token0.balanceOf(lp1), 90e18);
    assertEq(token1.balanceOf(lp1), 90e18);

    // 檢查 simpleSwap 的 token0 和 token1 餘額是否符合預期，斷言擁有 10e18 單位
    assertEq(token0.balanceOf(address(simpleSwap)), 10e18);
    assertEq(token1.balanceOf(address(simpleSwap)), 10e18);
    vm.stopPrank();

    // 模擬 lp2 的身份進行操作，替流動池增加 5e18 的流動性
    vm.startPrank(lp2);
    simpleSwap.addLiquidity2(5e18);

    // 檢查 lp2 的 token0 和 token1 餘額是否符合預期，斷言剩下 95e18 單位
    assertEq(token0.balanceOf(lp2), 95e18);
    assertEq(token1.balanceOf(lp2), 95e18);

    // 檢查 simpleSwap 的 token0 和 token1 餘額是否符合預期，斷言擁有增加後的 15e18 單位
    assertEq(token0.balanceOf(address(simpleSwap)), 15e18);
    assertEq(token1.balanceOf(address(simpleSwap)), 15e18);
    vm.stopPrank();
  }

  // 測試 swap2 功能函式的正確情境，代幣 1:1 兌換
  function testSwap2() public {
    // 先添加流動性才有流動性可以 swap 此時
    // lp1 有 90e18 的 token0, token1
    // lp2 有 95e18 的 token0, token1
    // simpleSwap 有 15e18 的 token0, token1
    testAddLiquidity2();

    // 模擬 user 進行 swap，用 token0 3e18 交換 token1 3e18
    vm.startPrank(user);
    simpleSwap.swap(address(token0), 3e18);

    // 斷言目前 user 擁有 97e18 token0 與 103e18 token1
    assertEq(token0.balanceOf(user), 97e18);
    assertEq(token1.balanceOf(user), 103e18);

    // 斷言目前 simpleSwap 擁有 18e18 token0 與 12e18 token1
    assertEq(token0.balanceOf(address(simpleSwap)), 18e18);
    assertEq(token1.balanceOf(address(simpleSwap)), 12e18);
    vm.stopPrank();
  }

  // 測試 removeLiquidity2 移除流動性功能函式的正確情境，“需要”考量 lp1, lp2 添加的佔比問題
  function testRemoveLiquidity2() public {
    // 先觸發 testSwap2，目前
    // lp1 投入 10e18 的 token0, token1，佔比 10/15 = 2/3。本身剩餘 90e18
    // lp2 投入 5e18 的 token0, token1，佔比 5/15 = 1/3。本身剩餘 95e18
    // simpleSwap 為 18e18 的 token0、12e18 的 token1
    testSwap2();

    // 模擬 lp1 身份進行移除流動性，亦即把代幣從 simpleSwap 取回
    vm.startPrank(lp1);
    simpleSwap.removeLiquidity2();

    // 斷言 lp1 擁有 18e18 * 2/3 + 90e18 token0 = 102e18
    assertEq(token0.balanceOf(lp1), 102e18);
    // 斷言 lp1 擁有 12e18 * 2/3 + 90e18 token1 = 98e18
    assertEq(token1.balanceOf(lp1), 98e18);
    vm.stopPrank();

    // 模擬 lp2 身份進行移除流動性，亦即把代幣從 simpleSwap 取回
    vm.startPrank(lp2);
    simpleSwap.removeLiquidity1();

    // 斷言 lp2 取出剩餘的 token0 + 95e18 token0 = 101e18
    assertEq(token0.balanceOf(lp2), 101e18);
    // 斷言 lp2 取出剩餘的 token1 + 95e18 token1 = 99e18
    assertEq(token1.balanceOf(lp2), 99e18);
    vm.stopPrank();

    // simpleSwap token 總數剩餘 0
    assertEq(token0.balanceOf(address(simpleSwap)), 0);
    assertEq(token1.balanceOf(address(simpleSwap)), 0);
  }
}