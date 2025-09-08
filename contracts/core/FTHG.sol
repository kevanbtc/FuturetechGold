// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title FTHG - Future Tech Holdings Gold Token  
 * @notice ERC-20 token representing 1kg of gold per token (1e18 = 1kg)
 * @dev Only authorized minters can create tokens, transfers disabled during cliff
 */
contract FTHG is ERC20, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    /// @notice Maps address to cliff end timestamp (no transfers until cliff ends)
    mapping(address => uint256) public cliffEnd;
    
    event CliffSet(address indexed user, uint256 cliffEndTime);
    event CliffCleared(address indexed user);
    
    error TransferDuringCliff();
    error OnlyMinter();
    error OnlyPauser();
    
    constructor(
        address admin,
        address initialMinter
    ) ERC20("Future Tech Holdings Gold", "FTH-G", 18) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, initialMinter);
        _grantRole(PAUSER_ROLE, admin);
    }
    
    /**
     * @notice Mint tokens to specified address (only authorized minters)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint (1e18 = 1kg gold)
     */
    function mint(address to, uint256 amount) external whenNotPaused {
        if (!hasRole(MINTER_ROLE, msg.sender)) revert OnlyMinter();
        _mint(to, amount);
    }
    
    /**
     * @notice Set cliff period for address (no transfers until cliff ends)
     * @param user Address to set cliff for
     * @param cliffEndTime Timestamp when cliff ends
     */
    function setCliff(address user, uint256 cliffEndTime) external {
        if (!hasRole(MINTER_ROLE, msg.sender)) revert OnlyMinter();
        cliffEnd[user] = cliffEndTime;
        emit CliffSet(user, cliffEndTime);
    }
    
    /**
     * @notice Clear cliff for address (allow transfers)
     * @param user Address to clear cliff for
     */
    function clearCliff(address user) external {
        if (!hasRole(MINTER_ROLE, msg.sender)) revert OnlyMinter();
        delete cliffEnd[user];
        emit CliffCleared(user);
    }
    
    /**
     * @notice Check if address is currently in cliff period
     * @param user Address to check
     * @return True if user is in cliff period
     */
    function isInCliff(address user) public view returns (bool) {
        return block.timestamp < cliffEnd[user];
    }
    
    /**
     * @notice Pause all token operations (emergency use)
     */
    function pause() external {
        if (!hasRole(PAUSER_ROLE, msg.sender)) revert OnlyPauser();
        _pause();
    }
    
    /**
     * @notice Unpause token operations
     */
    function unpause() external {
        if (!hasRole(PAUSER_ROLE, msg.sender)) revert OnlyPauser();
        _unpause();
    }
    
    /**
     * @notice Override transfer to enforce cliff restrictions
     */
    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        if (isInCliff(msg.sender)) revert TransferDuringCliff();
        return super.transfer(to, amount);
    }
    
    /**
     * @notice Override transferFrom to enforce cliff restrictions
     */
    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused returns (bool) {
        if (isInCliff(from)) revert TransferDuringCliff();
        return super.transferFrom(from, to, amount);
    }
}