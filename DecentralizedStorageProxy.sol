// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Storage Proxy
 * @notice Upgradeable proxy with explicit function interface
 * @dev Remix-compatible proxy contract
 */
contract DecentralizedStorageProxy {
    
    // Storage layout - matches logic contract exactly
    address public owner;
    address public logicContract;
    mapping(string => string) public pages;
    mapping(string => uint256) public lastUpdated;
    mapping(string => bool) private _pageExists;
    uint256 public totalPagesCount;
    
    // Events
    event LogicUpgraded(address indexed oldLogic, address indexed newLogic);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    /**
     * @notice Initialize proxy
     */
    constructor(address _logicContract) {
        require(_logicContract != address(0), "Zero address");
        owner = msg.sender;
        logicContract = _logicContract;
        emit LogicUpgraded(address(0), _logicContract);
    }
    
    // ==========================================
    // PROXY MANAGEMENT
    // ==========================================
    
    /**
     * @notice Upgrade logic contract
     */
    function upgrade(address _newLogic) external onlyOwner {
        require(_newLogic != address(0), "Zero address");
        require(_newLogic != logicContract, "Same logic");
        
        address oldLogic = logicContract;
        logicContract = _newLogic;
        emit LogicUpgraded(oldLogic, _newLogic);
    }
    
    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        require(newOwner != owner, "Same owner");
        
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    // ==========================================
    // CONTENT MANAGEMENT (delegated to logic)
    // ==========================================
    
    /**
     * @notice Store/update page
     */
    function setPage(string calldata pageId, string calldata content) external onlyOwner {
        _delegateCall(abi.encodeWithSignature("setPage(string,string)", pageId, content));
    }
    
    /**
     * @notice Get page content
     */
    function getPage(string calldata pageId) external view returns (string memory) {
        bytes memory data = _staticCall(abi.encodeWithSignature("getPage(string)", pageId));
        return abi.decode(data, (string));
    }
    
    /**
     * @notice Get page with metadata
     */
    function getPageInfo(string calldata pageId) external view returns (string memory content, uint256 blockNumber) {
        bytes memory data = _staticCall(abi.encodeWithSignature("getPageInfo(string)", pageId));
        return abi.decode(data, (string, uint256));
    }
    
    /**
     * @notice Batch update pages
     */
    function setPages(string[] calldata pageIds, string[] calldata contents) external onlyOwner {
        _delegateCall(abi.encodeWithSignature("setPages(string[],string[])", pageIds, contents));
    }
    
    /**
     * @notice Check if page exists
     */
    function pageExists(string calldata pageId) external view returns (bool) {
        bytes memory data = _staticCall(abi.encodeWithSignature("pageExists(string)", pageId));
        return abi.decode(data, (bool));
    }
    
    /**
     * @notice Delete page
     */
    function deletePage(string calldata pageId) external onlyOwner {
        _delegateCall(abi.encodeWithSignature("deletePage(string)", pageId));
    }
    
    /**
     * @notice Get last updated block
     */
    function getLastUpdated(string calldata pageId) external view returns (uint256) {
        bytes memory data = _staticCall(abi.encodeWithSignature("getLastUpdated(string)", pageId));
        return abi.decode(data, (uint256));
    }
    
    /**
     * @notice Get total pages
     */
    function getTotalPages() external view returns (uint256) {
        bytes memory data = _staticCall(abi.encodeWithSignature("getTotalPages()"));
        return abi.decode(data, (uint256));
    }
    
    /**
     * @notice Get version
     */
    function getVersion() external view returns (string memory) {
        bytes memory data = _staticCall(abi.encodeWithSignature("getVersion()"));
        return abi.decode(data, (string));
    }
    
    // ==========================================
    // INTERNAL DELEGATION HELPERS
    // ==========================================
    
    /**
     * @notice Internal delegate call
     */
    function _delegateCall(bytes memory data) private {
        (bool success, ) = logicContract.delegatecall(data);
        require(success, "Delegate call failed");
    }
    
    /**
     * @notice Internal static call
     */
    function _staticCall(bytes memory data) private view returns (bytes memory) {
        (bool success, bytes memory result) = logicContract.staticcall(data);
        require(success, "Static call failed");
        return result;
    }
    
    // ==========================================
    // UTILITY FUNCTIONS
    // ==========================================
    
    /**
     * @notice Get current logic address
     */
    function getLogicContract() external view returns (address) {
        return logicContract;
    }
    
    /**
     * @notice Get current owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
    
    // ==========================================
    // FALLBACK & RECEIVE
    // ==========================================
    
    /**
     * @notice Fallback function
     */
    fallback() external payable {
        address logic = logicContract;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), logic, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    /**
     * @notice Receive function
     */
    receive() external payable {}
}