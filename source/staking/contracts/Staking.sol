//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.6;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/Math.sol";

contract Staking is Ownable {
  using SafeERC20 for ERC20;
  using SafeMath for uint256;
  struct Stake {
    uint256 duration;
    uint256 cliff;
    uint256 initial;
    uint256 balance;
    uint256 timestamp;
  }

  // Token to be staked
  ERC20 public immutable token;

  // Vesting duration and cliff
  uint256 public duration;
  uint256 public cliff;

  // Mapping of account to stakes
  mapping(address => Stake[]) public accountStakes;

  // ERC-20 token properties
  string public name;
  string public symbol;

  // ERC-20 Transfer event
  event Transfer(address indexed from, address indexed to, uint256 tokens);

  constructor(
    ERC20 _token,
    string memory _name,
    string memory _symbol,
    uint256 _duration,
    uint256 _cliff
  ) public {
    token = _token;
    name = _name;
    symbol = _symbol;
    duration = _duration;
    cliff = _cliff;
  }

  function setSchedule(uint256 _duration, uint256 _cliff) external onlyOwner {
    duration = _duration;
    cliff = _cliff;
  }

  function stake(uint256 amount) external {
    stakeFor(msg.sender, amount);
  }

  function stakeFor(address account, uint256 amount) public {
    require(amount > 0, "AMOUNT_INVALID");
    accountStakes[account].push(
      Stake(duration, cliff, amount, amount, block.timestamp)
    );
    token.safeTransferFrom(account, address(this), amount);
    emit Transfer(address(0), account, amount);
  }

  function extend(uint256 index, uint256 amount) external {
    extendFor(index, msg.sender, amount);
  }

  function extendFor(
    uint256 index,
    address account,
    uint256 amount
  ) public {
    require(amount > 0, "AMOUNT_INVALID");

    Stake storage selected = accountStakes[msg.sender][index];

    uint256 newInitial = selected.initial.add(amount);
    uint256 newBalance = selected.balance.add(amount);
    uint256 newTimestamp =
      selected.timestamp +
        amount.mul(block.timestamp.sub(selected.timestamp)).div(newInitial);

    accountStakes[msg.sender][index] = Stake(
      duration,
      cliff,
      newInitial,
      newBalance,
      newTimestamp
    );
    token.safeTransferFrom(account, address(this), amount);
    emit Transfer(address(0), account, amount);
  }

  function unstake(uint256 index, uint256 amount) external {
    Stake storage selected = accountStakes[msg.sender][index];
    require(
      block.timestamp.sub(selected.timestamp) >= selected.cliff,
      "CLIFF_NOT_REACHED"
    );
    uint256 withdrawableAmount = available(msg.sender, index);
    require(amount <= withdrawableAmount, "AMOUNT_EXCEEDS_AVAILABLE");
    selected.balance = selected.balance.sub(amount);

    if (selected.balance == 0) {
      Stake[] storage stakes = accountStakes[msg.sender];
      Stake storage last = stakes[stakes.length.sub(1)];
      selected.duration = last.duration;
      selected.cliff = last.cliff;
      selected.initial = last.initial;
      selected.balance = last.balance;
      selected.timestamp = last.timestamp;
      accountStakes[msg.sender].pop();
    }
    token.transfer(msg.sender, amount);
    emit Transfer(msg.sender, address(0), amount);
  }

  function vested(address account, uint256 index)
    public
    view
    returns (uint256)
  {
    Stake storage stakeData = accountStakes[account][index];
    if (block.timestamp.sub(stakeData.timestamp) > duration) {
      return stakeData.initial;
    }
    return
      stakeData.initial.mul(block.timestamp.sub(stakeData.timestamp)).div(
        stakeData.duration
      );
  }

  function available(address account, uint256 index)
    public
    view
    returns (uint256)
  {
    Stake memory selected = accountStakes[account][index];

    if (block.timestamp.sub(selected.timestamp) < selected.cliff) {
      return 0;
    }
    return vested(account, index) - (selected.initial - selected.balance);
  }

  function getStakes(address account)
    external
    view
    returns (Stake[] memory stakes)
  {
    uint256 length = accountStakes[account].length;
    stakes = new Stake[](length);
    for (uint256 i = 0; i < length; i++) {
      stakes[i] = accountStakes[account][i];
    }
    return stakes;
  }

  function totalSupply() external view returns (uint256) {
    return token.balanceOf(address(this));
  }

  function balanceOf(address account) external view returns (uint256 total) {
    Stake[] memory stakes = accountStakes[account];
    for (uint256 i = 0; i < stakes.length; i++) {
      total = total.add(stakes[i].balance);
    }
    return total;
  }

  function decimals() external view returns (uint8) {
    return token.decimals();
  }
}
