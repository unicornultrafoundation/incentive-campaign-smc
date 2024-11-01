// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import "../libs/TransferHelper.sol";

contract AirdropPool is Ownable, AccessControl, EIP712 {
    using ECDSA for bytes32;
    bytes32 public constant AIRDROP_ADMIN = keccak256("AIRDROP_ADMIN");

    uint256 public constant AIRDROP_AMOUNT = 5 * 1e18;
    // mapping user => claimed
    mapping(address => bool) public users;

    event SendAir(address indexed to);

    constructor() EIP712("AirdropPool", "1") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyMasterAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "DEFAULT_ADMIN_ROLE"
        );
        _;
    }

    function sendAir(address _to) external {
        require(hasRole(AIRDROP_ADMIN, _msgSender()), "AIRDROP_ADMIN");
        require(!users[_to], "Already sent");
        TransferHelper.safeTransferNative(_to, AIRDROP_AMOUNT);
        users[_to] = true;
        emit SendAir(_to);
    }

    function hash(
        address _userAddr,
        uint256 _expiresAt
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(_userAddr, address(this), _expiresAt))
            );
    }

    function verify(
        uint256 _expiresAt,
        bytes memory _signature
    ) public view returns (address) {
        return _verify(_expiresAt, _signature);
    }

    function _verify(
        uint256 _expiresAt,
        bytes memory _signature
    ) private view returns (address) {
        bytes32 digest = hash(msg.sender, _expiresAt);
        return digest.toEthSignedMessageHash().recover(_signature);
    }

    receive() external payable {}

    function emergencyWithdrawU2U(
        address _to,
        uint256 _amount
    ) external onlyMasterAdmin {
        TransferHelper.safeTransferNative(_to, _amount);
    }
}
