// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AirSwap Staking: Stake and Unstake Tokens
 * @notice https://www.airswap.io/
 */
contract Staking is Ownable {
  using SafeERC20 for ERC20;
  using SafeMath for uint256;
  struct Stake {
    uint256 duration;
    // uint256 initial;
    uint256 balance;
    uint256 timestamp;
  }

  // Token to be staked
  ERC20 public immutable token;

  // Vesting duration min and max
  uint256 public vestingLengthMin;
  uint256 public vestingLengthMax;
  uint256 public vestingLengthDefault;

  // Mapping of account to stakes
  mapping(address => Stake) public allStakes;

  // Mapping of account to delegate
  mapping(address => address) public accountDelegate;
  mapping(address => address) public delegateAccount;
  mapping(address => bool) public isDelegate;

  // ERC-20 token properties
  string public name;
  string public symbol;

  // ERC-20 Transfer event
  event Transfer(address indexed from, address indexed to, uint256 tokens);

  /**
   * @notice Constructor
   * @param _token address
   * @param _name string
   * @param _symbol string
   * @param _vestingLengthMin uint256
   * @param _vestingLengthMax uint256
   * @param _vestingLengthDefault uint256
   */
  constructor(
    ERC20 _token,
    string memory _name,
    string memory _symbol,
    uint256 _vestingLengthMin,
    uint256 _vestingLengthMax,
    uint256 _vestingLengthDefault
  ) {
    token = _token;
    name = _name;
    symbol = _symbol;
    setVesting(_vestingLengthMin, _vestingLengthMax, _vestingLengthDefault);
  }

  /**
   * @notice Set metadata config
   * @param _name string
   * @param _symbol string
   */
  function setMetaData(string memory _name, string memory _symbol)
    external
    onlyOwner
  {
    name = _name;
    symbol = _symbol;
  }

  /**
   * @notice Add delegate for account
   * @param delegate address
   */
  function addDelegate(address delegate) external {
    require(!isDelegate[delegate], "ALREADY_DELEGATE");
    require(allStakes[delegate].balance == 0, "ALREADY_STAKING");
    accountDelegate[msg.sender] = delegate;
    isDelegate[delegate] = true;
    delegateAccount[delegate] = msg.sender;
  }

  /**
   * @notice Remove delegate for account
   * @param delegate address
   */
  function removeDelegate(address delegate) external {
    require(accountDelegate[msg.sender] == delegate, "NOT_DELEGATE");
    accountDelegate[msg.sender] = address(0);
    isDelegate[delegate] = false;
    delegateAccount[delegate] = address(0);
  }

  /**
   * @notice Stake tokens
   * @param amount uint256
   */
  function stake(uint256 amount, uint256 duration) external {
    if (isDelegate[msg.sender]) {
      require(this.balanceOf(delegateAccount[msg.sender]) == 0, "ALREADY_STAKED");
      _stake(delegateAccount[msg.sender], amount, duration);
    } else {
      require(this.balanceOf(msg.sender) == 0,"ALREADY_STAKED");
      _stake(msg.sender, amount, duration);
    }
  }

  /**
   * @notice Extend a stake
   * @param amount uint256
   */
  function extend(uint256 amount) external {
    if (isDelegate[msg.sender]) {
      _extend(delegateAccount[msg.sender], amount, vestingLengthDefault);
    } else {
      _extend(msg.sender, amount, vestingLengthDefault);
    }
  }

  /**
   * @notice Unstake multiple
   * @param amount uint256
   */
  function unstake(uint256 amount) external {
    uint256 totalAmount = 0;
    address account;
    isDelegate[msg.sender]
      ? account = delegateAccount[msg.sender]
      : account = msg.sender;
    _unstake(account, amount);
    totalAmount += amount;

    if (totalAmount > 0) {
      token.transfer(account, totalAmount);
      emit Transfer(account, address(0), totalAmount);
    }
  }

  /**
   * @notice Stake for an account
   * @param account address
   */
  function getStakes(address account)
    external
    view
    returns (Stake memory accountStake)
  {
    return allStakes[account];
  }

  /**
   * @notice Total balance of all accounts (ERC-20)
   */
  function totalSupply() external view returns (uint256) {
    return token.balanceOf(address(this));
  }

  /**
   * @notice Balance of an account (ERC-20)
   */
  function balanceOf(address account) external view returns (uint256 total) {
    return allStakes[account].balance;
  }

  /**
   * @notice Decimals of underlying token (ERC-20)
   */
  function decimals() external view returns (uint8) {
    return token.decimals();
  }

  /**
   * @notice Set vesting config
   * @param _vestingLengthMin uint256
   * @param _vestingLengthMax uint256
   * @param _vestingLengthDefault uint256
   */
  function setVesting(
    uint256 _vestingLengthMin,
    uint256 _vestingLengthMax,
    uint256 _vestingLengthDefault
  ) public onlyOwner {
    require(_vestingLengthMin < _vestingLengthMax, "INVALID_VESTING");
    require(
      _vestingLengthMin < _vestingLengthDefault &&
        _vestingLengthMax > _vestingLengthDefault,
      "INVALID_DEFAULTDURATION"
    );
    vestingLengthMin = _vestingLengthMin;
    vestingLengthMax = _vestingLengthMax;
    vestingLengthDefault = _vestingLengthDefault;
  }

  /**
   * @notice Stake tokens for an account
   * @param account address
   * @param amount uint256
   */
  function stakeFor(address account, uint256 amount) public {
    _stake(account, amount, vestingLengthDefault);
  }

  /**
   * @notice Extend a stake for an account
   * @param account address
   * @param amount uint256
   */
  function extendFor(address account, uint256 amount) public {
    _extend(account, amount, vestingLengthDefault);
  }

  /**
   * @notice Available amount for an account
   * @param account uint256
   */
  function available(address account) public view returns (uint256) {
    Stake storage selected = allStakes[account];
    uint256 _available = (block.timestamp.sub(selected.timestamp))
      .mul(selected.balance)
      .div(selected.duration);
    if (_available >= allStakes[account].balance) {
      return allStakes[account].balance;
    } else {
      return _available;
    }
  }

  /**
   * @notice Stake tokens for an account
   * @param account address
   * @param amount uint256
   */
  function _stake(address account, uint256 amount, uint256 duration) internal {
    require(amount > 0, "AMOUNT_INVALID");
    require(allStakes[account].balance == 0, "STAKE_ALREADY");
    require(
      vestingLengthMin < duration &&
        vestingLengthMax > duration,
      "INVALID_DURATION"
    );
    allStakes[account].duration = duration;
    allStakes[account].balance = amount;
    allStakes[account].timestamp = block.timestamp;
    token.safeTransferFrom(msg.sender, address(this), amount);
    emit Transfer(address(0), account, amount);
  }

  /**
   * @notice Extend a stake
   * @param account address
   * @param amount uint256
   * @param extendDuration uint256
   */
  function _extend(
    address account,
    uint256 amount,
    uint256 extendDuration
  ) internal {
    Stake storage selected = allStakes[account];
    require(this.balanceOf(account) > 0,"NOT_STAKED");
    require(amount > 0, "AMOUNT_INVALID");
    require(extendDuration >= selected.duration, "DURATION_INVALID");
    uint256 nowAvailable = available(account);
    selected.balance = selected.balance.add(amount);
    if (selected.duration != extendDuration) {
      selected.duration = extendDuration;
    }
    selected.timestamp = block.timestamp.sub(
      nowAvailable.mul(selected.duration).div(selected.balance)
    );
    token.safeTransferFrom(msg.sender, address(this), amount);
    emit Transfer(address(0), account, amount);
  }

  /**
   * @notice Unstake tokens
   * @param account address
   * @param amount uint256
   */
  function _unstake(address account, uint256 amount) internal {
    Stake storage selected = allStakes[account];
    require(amount <= available(account), "AMOUNT_EXCEEDS_AVAILABLE");
    selected.balance = selected.balance.sub(amount);
  }
}
