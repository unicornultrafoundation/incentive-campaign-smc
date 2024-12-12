// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../libs/TransferHelper.sol";
import "./IncentivePoolInterface.sol";

contract IncentivePoolV2 is
    Ownable,
    Pausable,
    ReentrancyGuard,
    AccessControl,
    EIP712
{
    using ECDSA for bytes32;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant POOL_SIGNER = keccak256("POOL_SIGNER");

    struct UserInfo {
        uint256 totalStaked;
        uint256 latestHarvest;
        uint256 totalClaimed;
        uint256 debt;
    }

    uint256 public constant MAX_USDT_POOL_CAP = 1_500_000 * 1e6;
    uint256 public constant MAX_U2U_REWARDS = 10_000_000 * 1e18;
    uint256 public constant MIN_STAKE_AMOUNT = 10 * 1e6;
    uint256 public constant MAX_STAKE_AMOUNT = 10000 * 1e6;
    uint256 public constant MAX_STAKING_DAYS = 90 days;

    address public immutable pUSDT;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public claimableTime;
    uint256 public totalPoolStaked;

    uint256 public totalAmountOwedToUsers;

    address public incentivePoolV1;

    bool public ignoreSigner;

    EnumerableSet.AddressSet __unstakedUsers;

    // mapping address => user info
    mapping(address => UserInfo) private users_;

    mapping(bytes => bool) public usedSignatures;

    event Harvest(address indexed user, uint256 u2uRewards);
    event Stake(address indexed user, uint256 amount);
    event UnStake(address indexed user, uint256 amount);
    event LegacyUnStake(address indexed user, uint256 amount);

    event UpdateIgnoreSignerState(bool newState);
    event UpdateClaimableTime(uint256 time);

    constructor(
        address _pUSDT,
        address _incentivePoolV1
    ) EIP712("IncentivePool", "1") {
        require(_pUSDT != address(0), "pusdt address invalid");
        pUSDT = _pUSDT;
        incentivePoolV1 = _incentivePoolV1;

        claimableTime = IncentivePoolInterface(incentivePoolV1).claimableTime();
        startTime = IncentivePoolInterface(incentivePoolV1).startTime();
        endTime = IncentivePoolInterface(incentivePoolV1).endTime();
        totalPoolStaked = IncentivePoolInterface(incentivePoolV1)
            .totalPoolStaked();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyMasterAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "DEFAULT_ADMIN_ROLE"
        );
        _;
    }

    modifier onlyClaimableTime() {
        require(
            claimableTime > 0 && block.timestamp >= claimableTime,
            "Harvest: unclaimable time"
        );
        _;
    }

    // =================== EXTERNAL FUNCTION =================== //
    function setClaimableTime(uint256 _time) external onlyMasterAdmin {
        require(_time >= block.timestamp, "invalid claimable time");
        require(_time != claimableTime, "same current time");
        claimableTime = _time;
        emit UpdateClaimableTime(_time);
    }

    function setIgnoreSigner(bool _state) external onlyMasterAdmin {
        require(_state != ignoreSigner, "same current state");
        ignoreSigner = _state;
        emit UpdateIgnoreSignerState(_state);
    }

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
            uint256 totalClaimed,
            uint256 debt,
            uint256 legacyStaked
        )
    {
        return _getUserInfo(_user);
    }

    function unstake() external whenNotPaused nonReentrant {
        require(block.timestamp > endTime, "Pool is not ended");
        _unstake();
    }

    function legacyPoolUnstake() external whenNotPaused nonReentrant {
        require(block.timestamp > endTime, "Pool is not ended");
        require(!__unstakedUsers.contains(msg.sender), "already unstaked");
        _legacyPoolUnstake();
    }

    function stake(
        uint256 _amount,
        uint256 _expiresAt,
        bytes memory _signature
    ) external whenNotPaused nonReentrant {
        require(block.timestamp < endTime, "Pool is ended");
        require(_amount >= MIN_STAKE_AMOUNT, "not enough minimum stake amount");
        if (!ignoreSigner) {
            require(!usedSignatures[_signature], "Stake: signature reused");
            usedSignatures[_signature] = true;
            address _signer = _verifyStake(_expiresAt, _signature);
            require(hasRole(POOL_SIGNER, _signer), "Stake: only signer");
            require(_expiresAt >= block.timestamp, "Stake: signature expired");
        }
        _stake(_amount);
    }

    function harvest() external whenNotPaused nonReentrant onlyClaimableTime {
        _harvest();
    }

    function hashStake(
        address _userAddr,
        uint256 _expiresAt
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(_userAddr, address(this), _expiresAt))
            );
    }

    function verifyStake(
        uint256 _expiresAt,
        bytes memory _signature
    ) external view returns (address) {
        return _verifyStake(_expiresAt, _signature);
    }

    // ============================= INTERNAL HANDLE ============================= //
    function _verifyStake(
        uint256 _expiresAt,
        bytes memory _signature
    ) private view returns (address) {
        bytes32 digest = hashStake(msg.sender, _expiresAt);
        return digest.toEthSignedMessageHash().recover(_signature);
    }

    function _unstake() internal {
        _updateDebt();
        address _user = msg.sender;
        uint256 _staked = users_[_user].totalStaked;
        if (_staked > 0) {
            totalPoolStaked -= _staked;
            TransferHelper.safeTransfer(pUSDT, _user, _staked);
            users_[_user].totalStaked = 0;
            emit UnStake(_user, _staked);
        }
    }

    function _legacyPoolUnstake() internal {
        address _user = msg.sender;
        (uint256 _totalStaked, , , ) = IncentivePoolInterface(incentivePoolV1).getUserInfo(_user);
        if (_totalStaked > 0) {
            totalPoolStaked -= _totalStaked;
            TransferHelper.safeTransfer(pUSDT, _user, _totalStaked);
            emit LegacyUnStake(_user, _totalStaked);
        }
        __unstakedUsers.add(_user);
    }



    function _stake(uint256 _amount) internal {
        _updateDebt();
        address _user = msg.sender;
        users_[_user].totalStaked += _amount;
        (uint256 _totalStaked, , , ) = IncentivePoolInterface(incentivePoolV1).getUserInfo(_user);
        require(
            users_[_user].totalStaked + _totalStaked <= MAX_STAKE_AMOUNT,
            "staked amount over"
        );
        totalPoolStaked += _amount;
        require(totalPoolStaked <= MAX_USDT_POOL_CAP, "maximum pool cap");

        // Send USDT to staking pool
        TransferHelper.safeTransferFrom(pUSDT, _user, address(this), _amount);
        uint256 _rewards = _estimateRewards(_amount);
        totalAmountOwedToUsers += _rewards;
        emit Stake(_user, _amount);
    }

    function _estimateRewards(uint256 _amount) internal view returns (uint256) {
        uint256 _startAt = block.timestamp < startTime
            ? startTime
            : block.timestamp;
        uint256 timeRewards = endTime - _startAt;
        if (timeRewards == 0) {
            return 0;
        }
        return timeRewards.mul(_amount).mul(_rewardsRatePerSecond());
    }

    function _updateDebt() internal {
        address _user = msg.sender;
        uint256 _debtAmount = _pendingRewardsNoDebt(_user);
        users_[_user].latestHarvest = block.timestamp;
        if (_debtAmount > 0) {
            users_[_user].debt += _debtAmount;
        }
    }

    function _harvest() internal {
        address _user = msg.sender;
        uint256 _u2uRewards = _pendingRewards(_user);
        users_[_user].latestHarvest = block.timestamp;
        if (_u2uRewards > 0) {
            require(
                address(this).balance >= _u2uRewards,
                "Pool rewards insufficient"
            );
            users_[_user].totalClaimed += _u2uRewards;
            users_[_user].debt = 0;
            // Handle send rewards
            TransferHelper.safeTransferNative(_user, _u2uRewards);
            totalAmountOwedToUsers = totalAmountOwedToUsers > _u2uRewards
                ? totalAmountOwedToUsers.sub(_u2uRewards)
                : 0;
            emit Harvest(_user, _u2uRewards);
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
            uint256 totalClaimed,
            uint256 debt,
            uint256 legacyStaked
        )
    {
        UserInfo memory _userInfo = users_[_user];
        (uint256 _totalLegacyStaked, , , ) = IncentivePoolInterface(incentivePoolV1).getUserInfo(_user);
        totalStaked = _userInfo.totalStaked;
        latestHarvest = _userInfo.latestHarvest;
        totalClaimed = _userInfo.totalClaimed;
        debt = _userInfo.debt;
        legacyStaked = _totalLegacyStaked;
    }

    function _pendingRewards(address _user) internal view returns (uint256) {
        return _pendingRewardsNoDebt(_user) + users_[_user].debt;
    }

    function _pendingRewardsNoDebt(
        address _user
    ) internal view returns (uint256) {
        (uint256 totalStaked, uint256 latestHarvest, , ,) = _getUserInfo(_user);
        if (block.timestamp < startTime) return 0;
        if (latestHarvest < startTime) {
            latestHarvest = startTime;
        }
        if (latestHarvest > endTime) {
            latestHarvest = endTime;
        }
        if (0 == totalStaked) return 0;
        uint256 checkPointTime = block.timestamp < endTime
            ? block.timestamp
            : endTime;
        uint256 timeRewards = checkPointTime - latestHarvest;
        if (timeRewards == 0) {
            return 0;
        }
        return timeRewards.mul(totalStaked).mul(_rewardsRatePerSecond());
    }

    function _rewardsRatePerSecond() internal pure returns (uint256) {
        return MAX_U2U_REWARDS.div(MAX_USDT_POOL_CAP).div(MAX_STAKING_DAYS);
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
        require(_amount <= address(this).balance, "invalid amount");
        TransferHelper.safeTransferNative(_to, _amount);
    }
}
