// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IncentivePoolInterface {
    function startTime() external view returns (uint256);
    function endTime() external view returns (uint256);
    function claimableTime() external view returns (uint256);
    function totalPoolStaked() external view returns (uint256);

    function getUserInfo(
        address _user
    )
        external
        view
        returns (
            uint256 totalStaked,
            uint256 latestHarvest,
            uint256 totalClaimed,
            uint256 debt
        );
}
