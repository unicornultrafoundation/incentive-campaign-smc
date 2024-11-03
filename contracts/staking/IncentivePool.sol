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
import "../libs/TransferHelper.sol";

contract IncentivePool is
    Ownable,
    Pausable,
    ReentrancyGuard,
    AccessControl,
    EIP712
{
    using ECDSA for bytes32;
    using SafeMath for uint256;

    bytes32 public constant POOL_SIGNER = keccak256("POOL_SIGNER");

    struct UserInfo {
        uint256 totalStaked;
        uint256 latestHarvest;
        uint256 totalClaimed;
    }

    uint256 public MAX_USDT_POOL_CAP = 1_500_000 * 1e6;
    uint256 public MAX_U2U_REWARDS = 10_000_000 * 1e18;
    uint256 public MIN_STAKE_AMOUNT = 10 * 1e6;
    uint256 public MAX_STAKE_AMOUNT = 10000 * 1e6;
    uint256 public MAX_STAKING_DAYS = 90 days;


    address public pUSDT;
    uint256 public startTime;
    uint256 public endTime;

    uint256 public totalStaked;

    bool public ignoreSigner;

    // mapping address => user info
    mapping(address => UserInfo) private users_;

    mapping(bytes => bool) public usedSignatures;

    event Harvest(address indexed user, uint256 u2uRewards);
    event Stake(address indexed user, uint256 amount);
    event UnStake(address indexed user, uint256 amount);

    event UpdateIgnoreSignerState(bool newState);

    constructor(
        address _pUSDT,
        uint256 _startTime
    ) EIP712("IncentivePool", "1") {
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

    // =================== EXTERNAL FUNCTION =================== //
    function setIgnoreSigner(bool _state) external onlyMasterAdmin {
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
            uint256 totalClaimed
        )
    {
        return _getUserInfo(_user);
    }

    function unstake() external whenNotPaused nonReentrant {
        require(block.timestamp > endTime, "Pool is not ended");
        _unstake();
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

    function harvest() external whenNotPaused nonReentrant {
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
    ) public view returns (address) {
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
        unchecked {
            _harvest();
            address _user = msg.sender;
            uint256 _staked = users_[_user].totalStaked;
            if (_staked > 0) {
                totalStaked -= _staked;
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
            users_[_user].totalStaked += _amount;
            require(
                users_[_user].totalStaked <= MAX_STAKE_AMOUNT,
                "staked amount over"
            );
            totalStaked += _amount;
            require(totalStaked <= MAX_USDT_POOL_CAP, "maximum pool cap");

            // Send USDT to staking pool
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
            users_[_user].latestHarvest = block.timestamp;
            if (_u2uRewards > 0) {
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
}
