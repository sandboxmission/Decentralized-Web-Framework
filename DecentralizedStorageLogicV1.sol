// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Storage Logic V2
 * @notice Enhanced business logic with page discovery functionality
 * @dev Upgradeable logic contract for proxy pattern
 */
contract DecentralizedStorageLogicV2 {
    
    // Storage layout - MUST match proxy exactly
    address public owner;
    address public logicContract;
    mapping(string => string) public pages;
    mapping(string => uint256) public lastUpdated;
    mapping(string => bool) private _pageExists;
    uint256 public totalPagesCount;
    
    // NEW in V2: Page discovery
    string[] public pageIdsList;
    mapping(string => uint256) private _pageIndex; // pageId => index in pageIdsList
    
    // Events
    event PageUpdated(string indexed pageId, address indexed updater, uint256 blockNumber);
    event PageDeleted(string indexed pageId, uint256 blockNumber);
    event BatchUpdate(uint256 pageCount, uint256 blockNumber);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    /**
     * @notice Store or update single page
     */
    function setPage(string calldata pageId, string calldata content) external onlyOwner {
        require(bytes(pageId).length > 0, "Empty pageId");
        require(bytes(content).length > 0, "Empty content");
        
        // Track if this is a new page
        bool isNewPage = !_pageExists[pageId];
        
        pages[pageId] = content;
        lastUpdated[pageId] = block.number;
        _pageExists[pageId] = true;
        
        if (isNewPage) {
            totalPagesCount++;
            // Add to pageIdsList for discovery
            _pageIndex[pageId] = pageIdsList.length;
            pageIdsList.push(pageId);
        }
        
        emit PageUpdated(pageId, msg.sender, block.number);
    }
    
    /**
     * @notice Get page content
     */
    function getPage(string calldata pageId) external view returns (string memory) {
        return pages[pageId];
    }
    
    /**
     * @notice Get page with metadata
     */
    function getPageInfo(string calldata pageId) external view returns (string memory content, uint256 blockNumber) {
        return (pages[pageId], lastUpdated[pageId]);
    }
    
    /**
     * @notice Batch update multiple pages
     */
    function setPages(string[] calldata pageIds, string[] calldata contents) external onlyOwner {
        require(pageIds.length == contents.length, "Array length mismatch");
        require(pageIds.length > 0, "Empty arrays");
        
        for(uint256 i = 0; i < pageIds.length; i++) {
            require(bytes(pageIds[i]).length > 0, "Empty pageId");
            require(bytes(contents[i]).length > 0, "Empty content");
            
            bool isNewPage = !_pageExists[pageIds[i]];
            
            pages[pageIds[i]] = contents[i];
            lastUpdated[pageIds[i]] = block.number;
            _pageExists[pageIds[i]] = true;
            
            if (isNewPage) {
                totalPagesCount++;
                // Add to pageIdsList for discovery
                _pageIndex[pageIds[i]] = pageIdsList.length;
                pageIdsList.push(pageIds[i]);
            }
            
            emit PageUpdated(pageIds[i], msg.sender, block.number);
        }
        
        emit BatchUpdate(pageIds.length, block.number);
    }
    
    /**
     * @notice Check if page exists
     */
    function pageExists(string calldata pageId) external view returns (bool) {
        return _pageExists[pageId];
    }
    
    /**
     * @notice Get last updated block
     */
    function getLastUpdated(string calldata pageId) external view returns (uint256) {
        return lastUpdated[pageId];
    }
    
    /**
     * @notice Delete page
     */
    function deletePage(string calldata pageId) external onlyOwner {
        require(_pageExists[pageId], "Page not found");
        
        pages[pageId] = "";
        lastUpdated[pageId] = block.number;
        _pageExists[pageId] = false;
        totalPagesCount--;
        
        // Remove from pageIdsList
        uint256 indexToDelete = _pageIndex[pageId];
        uint256 lastIndex = pageIdsList.length - 1;
        
        if (indexToDelete != lastIndex) {
            // Move last element to deleted element's position
            string memory lastPageId = pageIdsList[lastIndex];
            pageIdsList[indexToDelete] = lastPageId;
            _pageIndex[lastPageId] = indexToDelete;
        }
        
        pageIdsList.pop();
        delete _pageIndex[pageId];
        
        emit PageDeleted(pageId, block.number);
    }
    
    /**
     * @notice Get total pages count
     */
    function getTotalPages() external view returns (uint256) {
        return totalPagesCount;
    }
    
    // NEW V2 FUNCTIONS FOR PAGE DISCOVERY
    
    /**
     * @notice Get all page IDs
     */
    function getAllPageIds() external view returns (string[] memory) {
        return pageIdsList;
    }
    
    /**
     * @notice Get page ID by index
     */
    function getPageIdByIndex(uint256 index) external view returns (string memory) {
        require(index < pageIdsList.length, "Index out of bounds");
        return pageIdsList[index];
    }
    
    /**
     * @notice Get paginated page IDs
     */
    function getPageIds(uint256 offset, uint256 limit) external view returns (string[] memory) {
        require(offset < pageIdsList.length, "Offset out of bounds");
        
        uint256 end = offset + limit;
        if (end > pageIdsList.length) {
            end = pageIdsList.length;
        }
        
        string[] memory result = new string[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = pageIdsList[i];
        }
        
        return result;
    }
    
    /**
     * @notice Get pages with content (paginated)
     */
    function getPagesWithContent(uint256 offset, uint256 limit) external view returns (
        string[] memory pageIds,
        string[] memory contents,
        uint256[] memory lastUpdatedBlocks
    ) {
        require(offset < pageIdsList.length, "Offset out of bounds");
        
        uint256 end = offset + limit;
        if (end > pageIdsList.length) {
            end = pageIdsList.length;
        }
        
        uint256 resultLength = end - offset;
        pageIds = new string[](resultLength);
        contents = new string[](resultLength);
        lastUpdatedBlocks = new uint256[](resultLength);
        
        for (uint256 i = offset; i < end; i++) {
            string memory pageId = pageIdsList[i];
            pageIds[i - offset] = pageId;
            contents[i - offset] = pages[pageId];
            lastUpdatedBlocks[i - offset] = lastUpdated[pageId];
        }
    }
    
    /**
     * @notice Search pages by partial ID match
     */
    function searchPages(string calldata searchTerm) external view returns (string[] memory matchingIds) {
        bytes memory searchBytes = bytes(searchTerm);
        require(searchBytes.length > 0, "Empty search term");
        
        // First pass: count matches
        uint256 matchCount = 0;
        for (uint256 i = 0; i < pageIdsList.length; i++) {
            if (_contains(bytes(pageIdsList[i]), searchBytes)) {
                matchCount++;
            }
        }
        
        // Second pass: collect matches
        matchingIds = new string[](matchCount);
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < pageIdsList.length; i++) {
            if (_contains(bytes(pageIdsList[i]), searchBytes)) {
                matchingIds[currentIndex] = pageIdsList[i];
                currentIndex++;
            }
        }
    }
    
    /**
     * @notice Helper function to check if haystack contains needle
     */
    function _contains(bytes memory haystack, bytes memory needle) private pure returns (bool) {
        if (needle.length > haystack.length) return false;
        
        for (uint256 i = 0; i <= haystack.length - needle.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
    
    /**
     * @notice Get contract version
     */
    function getVersion() external pure returns (string memory) {
        return "v2.0.0";
    }
    
    /**
     * @notice Get contract features
     */
    function getFeatures() external pure returns (string[] memory) {
        string[] memory features = new string[](6);
        features[0] = "Page Discovery";
        features[1] = "Search Functionality";
        features[2] = "Pagination";
        features[3] = "Batch Operations";
        features[4] = "Content Management";
        features[5] = "Upgradeable Architecture";
        return features;
    }
}