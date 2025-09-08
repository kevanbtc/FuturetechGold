// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IWhitelistGate - Interface for Whitelist Management
 * @notice Interface for invite-only access control
 */
interface IWhitelistGate {
    
    /**
     * @notice Check if address is whitelisted
     * @param wallet Address to check
     * @return True if whitelisted
     */
    function isWhitelisted(address wallet) external view returns (bool);
    
    /**
     * @notice Get invitation details
     * @param wallet Address to check
     * @return inviter Address that invited
     * @return inviteCode Invitation code used
     * @return timestamp When invited
     */
    function getInvitationDetails(address wallet) external view returns (
        address inviter,
        bytes32 inviteCode,
        uint256 timestamp
    );
    
    /**
     * @notice Check if invite code is valid
     * @param inviteCode Code to validate
     * @return True if valid
     */
    function isValidInviteCode(bytes32 inviteCode) external view returns (bool);
}