// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ExampleNFT
 * @dev A simple ERC-721 implementation for testing token-bound accounts
 * @author SettleMint
 * @notice This contract is for demonstration and testing purposes only
 *
 * Features:
 * - Auto-incrementing token IDs
 * - Open minting (anyone can mint)
 * - Basic ERC-721 functionality
 *
 * @custom:security-contact security@settlemint.com
 */
contract ExampleNFT is ERC721, Ownable {
    /**
     * @notice Counter for auto-incrementing token IDs
     */
    uint256 private _nextTokenId;

    /**
     * @notice Base URI for token metadata
     */
    string private _baseTokenURI;

    /**
     * @notice Emitted when a new token is minted
     * @param to The recipient of the minted token
     * @param tokenId The ID of the minted token
     */
    event TokenMinted(address indexed to, uint256 indexed tokenId);

    /**
     * @notice Creates a new ExampleNFT contract
     * @param name The name of the NFT collection
     * @param symbol The symbol of the NFT collection
     * @param baseURI The base URI for token metadata
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _baseTokenURI = baseURI;
        _nextTokenId = 1; // Start token IDs at 1
    }

    /**
     * @notice Mints a new token to the specified address
     * @dev Anyone can call this function (for testing purposes)
     * @param to The address to mint the token to
     * @return tokenId The ID of the newly minted token
     */
    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextTokenId;
        unchecked {
            ++_nextTokenId;
        }

        _safeMint(to, tokenId);
        emit TokenMinted(to, tokenId);
    }

    /**
     * @notice Mints a token with a specific ID (owner only)
     * @dev Useful for testing specific token IDs
     * @param to The address to mint the token to
     * @param tokenId The specific token ID to mint
     */
    function mintWithId(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
        emit TokenMinted(to, tokenId);
    }

    /**
     * @notice Sets the base URI for token metadata
     * @param baseURI The new base URI
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @notice Returns the base URI for token metadata
     * @return The base URI string
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice Returns the next token ID that will be minted
     * @return The next token ID
     */
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @notice Returns the total number of tokens minted
     * @return The total supply (tokens minted so far)
     */
    function totalMinted() external view returns (uint256) {
        return _nextTokenId - 1;
    }
}
