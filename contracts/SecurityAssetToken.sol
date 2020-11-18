pragma solidity >= 0.6.0 < 0.7.0;

import "./AllowList.sol";
import "./ERC721.sol";
import "./IBondToken.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import { TokenAccessRoles } from "./TokenAccessRoles.sol";


/**
 * SecurityAssetToken represents an asset or deposit token, which has a
 * declared value
 */
contract SecurityAssetToken is ERC721, AccessControl {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    /// tokens values
    mapping(uint256 => uint256) private _values;

    /// value of all tokens summarized
    uint256 private _totalValue;

    /// bond token contract address
    address private _bond;

    /// allow list
    address private _allowList;

    /// token id counter
    Counters.Counter private _counter;

    /**
     * @param baseURI token base URI
     * @param miris external miris manager account
     * @param bond BondToken contract address
     */
    constructor(string memory baseURI, address miris,
        address bond, address allowList) public ERC721("SecurityAssetToken", "SAT") {
        _setBaseURI(baseURI);
        _bond = bond;
        _allowList = allowList;

        // setup roles
        _setupRole(TokenAccessRoles.minter(), miris);
        _setupRole(TokenAccessRoles.burner(), miris);
        _setupRole(TokenAccessRoles.transferer(), miris);
        _setupRole(TokenAccessRoles.admin(), miris);

        _setupRole(TokenAccessRoles.transferer(), bond);
    }

    /**
     * @return total value of all existing tokens
     */
    function totalValue() external view returns(uint256) { return _totalValue; }

    /**
     * mints a new SAT token and it's NFT bond token accordingly
     * @param to token owner
     * @param value collateral value
     * @param maturity datetime stamp when token's deposit value must be
     * returned
     */
    function mint(address to, uint256 value, uint256 maturity) external {
        // check role
        // only external account having minter role is allowed to mint tokens
        require(hasRole(TokenAccessRoles.minter(), _msgSender()),
            "user is not allowed to mint");

        // check if account is in allow list
        require(AllowList(_allowList).isAllowedAccount(to), "user is not allowed to receive tokens");

        uint256 tokenId = _counter.current();
        _counter.increment();

        _mint(to, tokenId);

        _values[tokenId] = value;
        _totalValue = _totalValue.add(value);

        // mint corresponding bond token
        IBondNFToken(_bond)
        .mint(
            tokenId,
            to,
            value.mul(75).div(100),
            maturity);
    }

    /**
     * burns security asset token
     */
    function burn(uint256 tokenId) external {
        require(hasRole(TokenAccessRoles.burner(), _msgSender()), "user is not allowed to burn");
        // get token properties
        uint256 value = _values[tokenId];

        // cannot burn non-existent token
        require(value > 0, "token doesn't exist");

        // cannot burn sat token when corresponding bond token still alive
        require(!IBondNFToken(_bond).hasToken(tokenId), "bond token is still alive");

        _burn(tokenId);

        // remove from _values
        delete _values[tokenId];

        // decrease total totalSupply (check for going below zero is conducted
        // inside of SafeMath's sub method)
        _totalValue = _totalValue.sub(value);
    }

    /**
     * Transfers token from one user to another.
     * @param from token owner address
     * @param to token receiver address
     * @param tokenId token id to transfer
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        _safeTransferFrom(
            _msgSender(),
            from,
            to,
            tokenId,
            "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        _safeTransferFrom(
            _msgSender(),
            from,
            to,
            tokenId,
            "");
    }

    function safeTransferFrom(address from, address to,
        uint256 tokenId, bytes memory _data) public override
    {
        _safeTransferFrom(
            _msgSender(),
            from,
            to,
            tokenId,
            _data);
    }

    function _isApproved(address spender, uint256 tokenId) private view returns(bool) {
        require(_exists(tokenId), "token does not exist");
        address owner = ownerOf(tokenId);
        return (getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _safeTransferFrom(
        address sender,
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data) private
    {
        require(hasRole(TokenAccessRoles.transferer(), sender), "user is not allowed to transfer");
        require(AllowList(_allowList).isAllowedAccount(to), "user is not allowed to receive tokens");
        require(_isApproved(to, tokenId), "transfer was not approved");

        _safeTransfer(
            from,
            to,
            tokenId,
            _data);

        IERC721(_bond)
        .safeTransferFrom(
            from,
            to,
            tokenId,
            _data);
    }
}