// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface ICheckpointToken {
    function user_checkpoint(address[2] calldata _accounts) external returns(bool);
}