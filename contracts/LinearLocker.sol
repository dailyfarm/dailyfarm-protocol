pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IRewardLocker.sol";

contract LinearRelease is Ownable, ReentrancyGuard, IRewardLocker {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct LockInfo {
    uint256 starttime;
    uint256 endtime;
    uint256 releaseStarttime;
    uint256 releaseEndtime;
    uint256 lockBps;
    bool valid;
  }

  IERC20 public token;
  LockInfo[] public lockInfo;

  mapping(uint256 => mapping(address => uint256)) private _locks;
  mapping(uint256 => mapping(address => uint256)) private _lastUnlockTime;

  event Lock(address indexed to, uint256 value);
  event Claim(address indexed to, uint256 value);

  constructor(
    IERC20 _token
  ) public {
    token = _token;
  }

  function addLockInfo(
    uint256 _starttime,
    uint256 _endtime,
    uint256 _releaseStarttime,
    uint256 _releaseEndtime,
    uint256 _lockBps
  ) public onlyOwner {
    lockInfo.push(
      LockInfo({
        starttime: _starttime,
        endtime: _endtime,
        releaseStarttime: _releaseStarttime,  
        releaseEndtime: _releaseEndtime,
        lockBps: _lockBps,
        valid: true
      })
    );
  }

  function clearLock(uint _lockId) public onlyOwner {
    lockInfo[_lockId].valid = false;
  }

  
  function lockOf(address _user) public view returns (uint256) {
    uint256 lockAmount = 0;
    for(uint256 i = 0; i < lockInfo.length; i++) {
      lockAmount = lockAmount.add(_locks[i][_user]);
    }
    return lockAmount;
  }

  function getLockAmount(
    address _user, 
    uint256 _time, 
    uint256 _amount
  ) public view override returns (uint256) {
    for (uint i = 0; i < lockInfo.length; i++) {
      LockInfo storage _lock = lockInfo[i];
      if (_lock.valid && _lock.starttime <= _time && _lock.endtime >= _time) {
        return _amount.mul(_lock.lockBps).div(10000);
      }
    }
    return 0;
  }


  function lock(
    address _user, 
    uint256 _time, 
    uint256 _amount
  ) public override nonReentrant {
    require(_user != address(0), "lock: no address(0)");
    token.safeTransferFrom(msg.sender, address(this), _amount);
    for (uint i = 0; i < lockInfo.length; i++) {
      LockInfo storage _lock = lockInfo[i];
      if (_lock.valid && _lock.starttime <= _time && _lock.endtime >= _time) {
        _locks[i][_user] = _locks[i][_user].add(_amount);
        if (_lastUnlockTime[i][_user] < _lock.releaseStarttime) {
          _lastUnlockTime[i][_user] = _lock.releaseStarttime;
        }
        emit Lock(_user, _amount);
        break;
      }
    }
  }

  function _pendingTokens(address _user, uint256 i) internal view returns (uint256) {
    if (_locks[i][_user] == 0) {
      return 0;
    }
    uint256 amount = 0;
    LockInfo storage _lock = lockInfo[i];
    if (block.timestamp < _lock.releaseStarttime) {
      amount = 0;
    }
    else if (block.timestamp >= _lock.releaseEndtime) {
      amount = _locks[i][_user];
    }
    else
    {
      uint256 releasedTime = block.timestamp.sub(_lastUnlockTime[i][_user]);
      uint256 timeLeft = _lock.releaseEndtime.sub(_lastUnlockTime[i][_user]);
      amount = _locks[i][_user].mul(releasedTime).div(timeLeft);
    }
    return amount;
  }

  function pendingTokens(address _user) public view returns (uint256) {
    uint256 amount = 0;
    for(uint256 i = 0; i < lockInfo.length; i++) {
      amount = amount.add(_pendingTokens(_user, i));
    }
    return amount;
  }

  function claim() public nonReentrant {
    uint256 amount = 0;
    for(uint256 i = 0; i < lockInfo.length; i++) {
      if (_locks[i][msg.sender] > 0) {
        uint256 _amount = _pendingTokens(msg.sender, i);
        _locks[i][msg.sender] = _locks[i][msg.sender].sub(_amount);
        _lastUnlockTime[i][msg.sender] = block.timestamp;
        amount = amount.add(_amount);
      }
    }

    token.safeTransfer(msg.sender, amount);
    emit Claim(msg.sender, amount);
  }
}