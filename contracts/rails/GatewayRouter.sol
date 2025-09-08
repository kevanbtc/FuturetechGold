// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title GatewayRouter - Multi-Chain Deposit Router
 * @notice Handles deposits from multiple chains (TRON USDT, ETH, etc) with proof verification
 * @dev Normalizes all deposits to USD accounting units for the subscription pool
 */
contract GatewayRouter is AccessControl, Pausable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    
    bytes32 public constant BRIDGE_OPERATOR_ROLE = keccak256("BRIDGE_OPERATOR_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    
    struct DepositProof {
        address user;           // Ethereum address to credit
        string fromChain;       // Source chain ("tron", "ethereum", "polygon")  
        string fromTxHash;      // Transaction hash on source chain
        address fromToken;      // Token address on source chain (or 0x0 for native)
        uint256 fromAmount;     // Amount on source chain (in token decimals)
        uint256 usdAmount;      // Equivalent USD amount (18 decimals)
        uint256 nonce;          // Unique nonce for replay protection
        uint256 timestamp;      // Proof timestamp
        bytes signature;        // Bridge operator signature
    }
    
    struct TokenConfig {
        address tokenAddress;   // ERC20 token address (or 0x0 for native ETH)
        uint8 decimals;        // Token decimals
        string symbol;         // Token symbol  
        bool active;           // Whether token is accepted
        uint256 minDeposit;    // Minimum deposit amount
        uint256 maxDeposit;    // Maximum deposit amount
    }
    
    // Supported deposit tokens
    mapping(bytes32 => TokenConfig) public supportedTokens;
    bytes32[] public activeTokenIds;
    
    // Cross-chain deposit tracking
    mapping(bytes32 => bool) public processedProofs; // proof hash => processed
    mapping(address => uint256) public userCredits;  // user => total USD credited
    mapping(string => uint256) public chainTotalDeposits; // chain => total deposits
    
    // Bridge operators for signature verification
    mapping(address => bool) public bridgeOperators;
    address[] public operatorList;
    
    // Fee structure
    uint256 public bridgeFeePercentBps = 50; // 0.5% bridge fee
    address public feeRecipient;
    
    // Accounting
    uint256 public totalUSDCredits;
    uint256 public totalFeeCollected;
    
    event TokenConfigured(bytes32 indexed tokenId, address token, string symbol, bool active);
    event CrossChainDepositProven(
        address indexed user,
        string fromChain,
        string fromTxHash,
        uint256 fromAmount,
        uint256 usdAmount,
        uint256 fee
    );
    event CreditsWithdrawn(address indexed user, uint256 amount, address token);
    event BridgeOperatorAdded(address indexed operator);
    event BridgeOperatorRemoved(address indexed operator);
    
    error InvalidProofSignature();
    error ProofAlreadyProcessed(bytes32 proofHash);
    error ProofExpired(uint256 timestamp, uint256 maxAge);
    error TokenNotSupported(bytes32 tokenId);
    error AmountBelowMinimum(uint256 amount, uint256 minimum);
    error AmountAboveMaximum(uint256 amount, uint256 maximum);
    error InsufficientCredits(address user, uint256 requested, uint256 available);
    error NotBridgeOperator(address caller);
    
    constructor(
        address admin,
        address _feeRecipient
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(BRIDGE_OPERATOR_ROLE, admin);
        _grantRole(TREASURY_ROLE, admin);
        
        feeRecipient = _feeRecipient;
        
        // Configure default supported tokens
        _configureSupportedToken("USDT_ETH", address(0), "USDT", 6, true, 100e6, 1000000e6); // Placeholder - set real address
        _configureSupportedToken("USDC_ETH", address(0), "USDC", 6, true, 100e6, 1000000e6); // Placeholder
        _configureSupportedToken("ETH_NATIVE", address(0), "ETH", 18, true, 0.1e18, 1000e18);
        _configureSupportedToken("USDT_TRON", address(0), "USDT", 6, true, 100e6, 1000000e6); // Virtual token for TRON
    }
    
    /**
     * @notice Configure a supported token
     * @param tokenId Unique identifier for the token
     * @param tokenAddress Token contract address (0x0 for native tokens)
     * @param symbol Token symbol
     * @param decimals Token decimals
     * @param active Whether token is active
     * @param minDeposit Minimum deposit amount  
     * @param maxDeposit Maximum deposit amount
     */
    function configureSupportedToken(
        bytes32 tokenId,
        address tokenAddress,
        string calldata symbol,
        uint8 decimals,
        bool active,
        uint256 minDeposit,
        uint256 maxDeposit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _configureSupportedToken(tokenId, tokenAddress, symbol, decimals, active, minDeposit, maxDeposit);
    }
    
    function _configureSupportedToken(
        bytes32 tokenId,
        address tokenAddress,
        string memory symbol,
        uint8 decimals,
        bool active,
        uint256 minDeposit,
        uint256 maxDeposit
    ) internal {
        require(maxDeposit >= minDeposit, "Invalid deposit limits");
        
        bool isNew = !supportedTokens[tokenId].active && 
                     supportedTokens[tokenId].tokenAddress == address(0);
        
        supportedTokens[tokenId] = TokenConfig({
            tokenAddress: tokenAddress,
            decimals: decimals,
            symbol: symbol,
            active: active,
            minDeposit: minDeposit,
            maxDeposit: maxDeposit
        });
        
        if (isNew && active) {
            activeTokenIds.push(tokenId);
        }
        
        emit TokenConfigured(tokenId, tokenAddress, symbol, active);
    }
    
    /**
     * @notice Process cross-chain deposit with operator signature proof
     * @param proof Deposit proof structure with signature
     */
    function processCrossChainDeposit(DepositProof calldata proof) external whenNotPaused {
        // Generate proof hash for replay protection
        bytes32 proofHash = keccak256(abi.encode(
            proof.user,
            proof.fromChain,
            proof.fromTxHash,
            proof.fromToken,
            proof.fromAmount,
            proof.usdAmount,
            proof.nonce,
            proof.timestamp
        ));
        
        // Check if proof already processed
        if (processedProofs[proofHash]) revert ProofAlreadyProcessed(proofHash);
        
        // Check proof age (24 hour max)
        if (block.timestamp - proof.timestamp > 86400) {
            revert ProofExpired(proof.timestamp, 86400);
        }
        
        // Verify bridge operator signature
        bytes32 messageHash = proofHash.toEthSignedMessageHash();
        address signer = messageHash.recover(proof.signature);
        
        if (!bridgeOperators[signer]) revert InvalidProofSignature();
        
        // Validate deposit limits (if applicable)
        bytes32 tokenId = keccak256(abi.encodePacked(proof.fromChain, "_", 
            proof.fromToken == address(0) ? "NATIVE" : "TOKEN"));
        
        if (supportedTokens[tokenId].active) {
            TokenConfig memory config = supportedTokens[tokenId];
            if (proof.fromAmount < config.minDeposit) {
                revert AmountBelowMinimum(proof.fromAmount, config.minDeposit);
            }
            if (proof.fromAmount > config.maxDeposit) {
                revert AmountAboveMaximum(proof.fromAmount, config.maxDeposit);
            }
        }
        
        // Calculate bridge fee
        uint256 fee = (proof.usdAmount * bridgeFeePercentBps) / 10000;
        uint256 netAmount = proof.usdAmount - fee;
        
        // Mark proof as processed
        processedProofs[proofHash] = true;
        
        // Credit user account
        userCredits[proof.user] += netAmount;
        totalUSDCredits += netAmount;
        totalFeeCollected += fee;
        chainTotalDeposits[proof.fromChain] += proof.usdAmount;
        
        emit CrossChainDepositProven(
            proof.user,
            proof.fromChain,
            proof.fromTxHash,
            proof.fromAmount,
            netAmount,
            fee
        );
    }
    
    /**
     * @notice Direct ETH deposit (auto-convert to USD credits)
     */
    receive() external payable whenNotPaused {
        require(msg.value >= supportedTokens[keccak256("ETH_NATIVE")].minDeposit, "Below minimum");
        require(msg.value <= supportedTokens[keccak256("ETH_NATIVE")].maxDeposit, "Above maximum");
        
        // This would integrate with ChainlinkPriceFeeds for ETH/USD conversion
        // For now, assume 1 ETH = 2000 USD for demonstration
        uint256 usdAmount = (msg.value * 2000e18) / 1e18; // Simplified conversion
        uint256 fee = (usdAmount * bridgeFeePercentBps) / 10000;
        uint256 netAmount = usdAmount - fee;
        
        userCredits[msg.sender] += netAmount;
        totalUSDCredits += netAmount;
        totalFeeCollected += fee;
        
        emit CrossChainDepositProven(
            msg.sender,
            "ethereum",
            "", // No tx hash for direct deposits
            msg.value,
            netAmount,
            fee
        );
    }
    
    /**
     * @notice Direct ERC20 token deposit
     * @param token Token address to deposit
     * @param amount Amount to deposit
     */
    function depositERC20(address token, uint256 amount) external whenNotPaused {
        bytes32 tokenId = keccak256(abi.encodePacked("ethereum_", token));
        TokenConfig memory config = supportedTokens[tokenId];
        
        require(config.active, "Token not supported");
        require(amount >= config.minDeposit, "Below minimum");
        require(amount <= config.maxDeposit, "Above maximum");
        
        // Transfer tokens to contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // Convert to USD (simplified - would use ChainlinkPriceFeeds)
        uint256 usdAmount = amount; // Assume 1:1 for stablecoins, adjust for others
        if (config.decimals != 18) {
            usdAmount = (amount * 1e18) / (10 ** config.decimals);
        }
        
        uint256 fee = (usdAmount * bridgeFeePercentBps) / 10000;
        uint256 netAmount = usdAmount - fee;
        
        userCredits[msg.sender] += netAmount;
        totalUSDCredits += netAmount;
        totalFeeCollected += fee;
        
        emit CrossChainDepositProven(
            msg.sender,
            "ethereum",
            "",
            amount,
            netAmount,
            fee
        );
    }
    
    /**
     * @notice Withdraw credited USD as tokens
     * @param amount Amount to withdraw (18 decimals)
     * @param token Token to withdraw (must be supported ERC20)
     */
    function withdrawCredits(uint256 amount, address token) external {
        if (userCredits[msg.sender] < amount) {
            revert InsufficientCredits(msg.sender, amount, userCredits[msg.sender]);
        }
        
        userCredits[msg.sender] -= amount;
        totalUSDCredits -= amount;
        
        // Convert USD amount to token amount
        bytes32 tokenId = keccak256(abi.encodePacked("ethereum_", token));
        TokenConfig memory config = supportedTokens[tokenId];
        require(config.active, "Token not supported");
        
        uint256 tokenAmount = amount;
        if (config.decimals != 18) {
            tokenAmount = (amount * (10 ** config.decimals)) / 1e18;
        }
        
        IERC20(token).transfer(msg.sender, tokenAmount);
        
        emit CreditsWithdrawn(msg.sender, amount, token);
    }
    
    /**
     * @notice Get user's current USD credit balance
     * @param user User address
     * @return balance USD balance (18 decimals)
     */
    function getCreditBalance(address user) external view returns (uint256 balance) {
        return userCredits[user];
    }
    
    /**
     * @notice Get total deposits by chain
     * @param chain Chain identifier
     * @return total Total deposits from chain
     */
    function getChainTotal(string calldata chain) external view returns (uint256 total) {
        return chainTotalDeposits[chain];
    }
    
    /**
     * @notice Add bridge operator
     * @param operator Operator address
     */
    function addBridgeOperator(address operator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!bridgeOperators[operator], "Operator already added");
        bridgeOperators[operator] = true;
        operatorList.push(operator);
        _grantRole(BRIDGE_OPERATOR_ROLE, operator);
        
        emit BridgeOperatorAdded(operator);
    }
    
    /**
     * @notice Remove bridge operator
     * @param operator Operator address
     */
    function removeBridgeOperator(address operator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bridgeOperators[operator], "Operator not found");
        bridgeOperators[operator] = false;
        _revokeRole(BRIDGE_OPERATOR_ROLE, operator);
        
        emit BridgeOperatorRemoved(operator);
    }
    
    /**
     * @notice Set bridge fee percentage
     * @param newFeeBps New fee in basis points
     */
    function setBridgeFee(uint256 newFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFeeBps <= 1000, "Fee too high"); // Max 10%
        bridgeFeePercentBps = newFeeBps;
    }
    
    /**
     * @notice Emergency pause all operations
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Resume operations
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Withdraw collected fees
     * @param amount Amount to withdraw
     * @param token Token to withdraw
     */
    function withdrawFees(uint256 amount, address token) external onlyRole(TREASURY_ROLE) {
        require(amount <= totalFeeCollected, "Insufficient fees");
        totalFeeCollected -= amount;
        
        if (token == address(0)) {
            payable(feeRecipient).transfer(amount);
        } else {
            IERC20(token).transfer(feeRecipient, amount);
        }
    }
}