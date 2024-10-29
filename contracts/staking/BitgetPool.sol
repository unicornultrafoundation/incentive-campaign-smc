// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../libs/TransferHelper.sol";

contract BitgetPool is Ownable, Pausable, ReentrancyGuard, AccessControl {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    struct UserInfo {
        uint256 totalStaked;
        uint256 latestHarvest;
        uint256 totalClaimed;
    }

    uint256 public MAX_USDT_POOL_CAP = 3_000_000 * 1e18;
    uint256 public MAX_U2U_REWARDS = 20_000_000 * 1e18;
    uint256 public MIN_STAKE_AMOUNT = 10 * 1e18;
    uint256 public MAX_STAKE_AMOUNT = 10000 * 1e18;
    uint256 public MAX_STAKING_DAYS = 90 days;

    address public pUSDT;
    uint256 public startTime;
    uint256 public endTime;

    // mapping address => user info
    mapping(address => UserInfo) private users_;

    event Harvest(address indexed user, uint256 u2uRewards);
    event Stake(address indexed user, uint256 amount);
    event UnStake(address indexed user, uint256 amount);

    constructor(address _pUSDT, uint256 _startTime) {
        pUSDT = _pUSDT;
        startTime = _startTime;
        endTime = _startTime + MAX_STAKING_DAYS;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyMasterAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "DEFAULT_ADMIN_ROLE"
        );
        _;
    }

    modifier onlyStarted {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Pool is not started"
        );
        _;
    }

    modifier onlyEnded() {
        require(block.timestamp > endTime, "Pool is not ended");
        _;
    }

    // =================== EXTERNAL FUNCTION =================== //

    function rewardsRatePerSecond() external view returns (uint256) {
        return _rewardsRatePerSecond();
    }

    function pendingRewards(address _user) external view returns (uint256) {
        return _pendingRewards(_user);
    }

    function getUserInfo(
        address _user
    )
        external
        view
        returns (
            uint256 totalStaked,
            uint256 latestHarvest,
            uint256 totalClaimed
        )
    {
        return _getUserInfo(_user);
    }

    function unstake() external onlyEnded {
        _unstake();
    }

    function stake(uint256 _amount) external onlyStarted {
        require(_amount >= MIN_STAKE_AMOUNT, "not enough minimum stake amount");
        _stake(_amount);
    }

    function harvest() external {
        _harvest();
    }

    // ============================= INTERNAL HANDLE ============================= //
    function _unstake() internal {
        unchecked {
            _harvest();
            address _user = msg.sender;
            uint256 _staked = users_[_user].totalStaked;
            if (_staked > 0) {
                TransferHelper.safeTransfer(pUSDT, _user, _staked);
                users_[_user].totalStaked = 0;
                emit UnStake(_user, _staked);
            }
        }
    }

    function _stake(uint256 _amount) internal {
        unchecked {
            _harvest();
            address _user = msg.sender;
            // Send USDT to staking pool

            users_[_user].totalStaked += _amount;
            require(users_[_user].totalStaked <= MAX_STAKE_AMOUNT, "staked amount over");
            TransferHelper.safeTransferFrom(
                pUSDT,
                _user,
                address(this),
                _amount
            );
            emit Stake(_user, _amount);
        }
    }

    function _harvest() internal {
        unchecked {
            address _user = msg.sender;
            uint256 _u2uRewards = _pendingRewards(_user);
            if (_u2uRewards > 0) {
                users_[_user].latestHarvest = block.timestamp;
                users_[_user].totalClaimed += _u2uRewards;
                // Handle send rewards
                TransferHelper.safeTransferNative(_user, _u2uRewards);
                emit Harvest(_user, _u2uRewards);
            }
        }
    }

    function _getUserInfo(
        address _user
    )
        internal
        view
        returns (
            uint256 totalStaked,
            uint256 latestHarvest,
            uint256 totalClaimed
        )
    {
        totalStaked = users_[_user].totalStaked;
        latestHarvest = users_[_user].latestHarvest;
        totalClaimed = users_[_user].totalClaimed;
    }

    function _pendingRewards(address _user) internal view returns (uint256) {
        unchecked {
            (uint256 totalStaked, uint256 latestHarvest, ) = _getUserInfo(
                _user
            );
            if (totalStaked == 0) return 0;
            uint256 timeRewards = block.timestamp - latestHarvest;
            return timeRewards.mul(totalStaked).mul(_rewardsRatePerSecond());
        }
    }

    function _rewardsRatePerSecond() internal view returns (uint256) {
        unchecked {
            return MAX_U2U_REWARDS.div(MAX_USDT_POOL_CAP).div(MAX_STAKING_DAYS);
        }
    }

    function pause() external onlyMasterAdmin whenNotPaused {
        _pause();
    }

    function unpause() external onlyMasterAdmin whenPaused {
        _unpause();
    }

    receive() external payable {}

    function emergencyWithdrawU2U(
        address _to,
        uint256 _amount
    ) external onlyMasterAdmin {
        TransferHelper.safeTransferNative(_to, _amount);
    }

    function emergencyWithdrawToken(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyMasterAdmin {
        TransferHelper.safeTransfer(_token, _to, _amount);
    }
}
