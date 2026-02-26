pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  mapping(address => mapping(address => uint256)) private allowances;
  address[] private holders;
  mapping(address => uint256) private holderIndex;
  mapping(address => uint256) private withdrawableDividend;

  function _addHolder(address addr) private {
    if (balanceOf[addr] > 0 && holderIndex[addr] == 0) {
      holders.push(addr);
      holderIndex[addr] = holders.length;
    }
  }

  function _removeHolder(address addr) private {
    if (balanceOf[addr] == 0 && holderIndex[addr] > 0) {
      uint256 index = holderIndex[addr].sub(1);
      uint256 lastIndex = holders.length.sub(1);
      if (index != lastIndex) {
        address lastHolder = holders[lastIndex];
        holders[index] = lastHolder;
        holderIndex[lastHolder] = index.add(1);
      }
      holders.pop();
      holderIndex[addr] = 0;
    }
  }

  function _transfer(address from, address to, uint256 value) private {
    if (value > 0) {
      balanceOf[from] = balanceOf[from].sub(value);
      balanceOf[to] = balanceOf[to].add(value);
      _removeHolder(from);
      _addHolder(to);
    }
  }

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(balanceOf[msg.sender] >= value, "Insufficient balance");
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(balanceOf[from] >= value, "Insufficient balance");
    require(allowances[from][msg.sender] >= value, "Insufficient allowance");
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "No ETH supplied");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _addHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "No balance to burn");
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _removeHolder(msg.sender);
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > holders.length) {
      return address(0);
    }
    return holders[index.sub(1)];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "No ETH supplied");
    require(totalSupply > 0, "No token supply");
    for (uint256 i = 0; i < holders.length; i++) {
      address holder = holders[i];
      uint256 share = msg.value.mul(balanceOf[holder]).div(totalSupply);
      withdrawableDividend[holder] = withdrawableDividend[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return withdrawableDividend[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = withdrawableDividend[msg.sender];
    require(amount > 0, "No dividend to withdraw");
    withdrawableDividend[msg.sender] = 0;
    dest.transfer(amount);
  }
}