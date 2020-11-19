pragma solidity >=0.6.0 <0.7.0;

import "./AllowList.sol";
import "./ERC721.sol";
import "./IBondToken.sol";
import "./IDDP.sol";
import "./SecurityAssetToken.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import {TokenAccessRoles} from "./TokenAccessRoles.sol";


contract BondToken is IBondNFToken, AccessControl, ERC721 {
    using SafeMath for uint256;

    uint256 private constant INTEREST_PERCENT = 7;

    struct BondInfo {
        uint256 value;
        uint256 interestPerSec;
        uint256 maturityEnds;
    }

    /// all tokens values
    mapping(uint256 => BondInfo) private _bondInfo;

    /// value of all tokens summarized
    uint256 private _totalValue;

    /// sat address
    address private _sat;

    /// ddp address
    address private _ddp;

    /// list of allowed accounts
    address _allowList;

    constructor(
        address admin,
        string memory baseURI,
        address allowList
    ) public ERC721("BondToken", "BND") {
        _setBaseURI(baseURI);
        _setupRole(TokenAccessRoles.admin(), admin);
        _allowList = allowList;
    }

    /// bond info accessors
    function getTokenValue(uint256 tokenId) external view returns (uint256) {
        return _bondInfo[tokenId].value;
    }

    function getTokenInterestPerSec(uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return _bondInfo[tokenId].interestPerSec;
    }

    function getTokenMaturityEnd(uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return _bondInfo[tokenId].maturityEnds;
    }

    function totalValue() external view returns (uint256) {
        return _totalValue;
    }

    function configure(address sat, address ddp) external {
        require(
            hasRole(TokenAccessRoles.admin(), _msgSender()),
            "caller isn't an administrator"
        );

        require(sat != address(0), "sat address is invalid");
        require(ddp != address(0), "ddp address is invalid");

        _setupRole(TokenAccessRoles.minter(), sat);
        _setupRole(TokenAccessRoles.transferer(), sat);

        _setupRole(TokenAccessRoles.burner(), ddp);
        _setupRole(TokenAccessRoles.transferer(), ddp);

        _ddp = ddp;
        _sat = sat;
    }

    function mint(
        uint256 tokenId,
        address to,
        uint256 value,
        uint256 maturity
    ) external override
    {
        require(
            hasRole(TokenAccessRoles.minter(), _msgSender()),
            "user is not allowed to mint"
        );

        _mint(to, tokenId);

        uint256 interestPerSec = value
        .mul(INTEREST_PERCENT).div(365 days).div(100);

        uint256 maturityEnds = block.timestamp.add(maturity);

        _bondInfo[tokenId] = BondInfo(
            {
                value: value,
                interestPerSec: interestPerSec,
                maturityEnds: maturityEnds
            });

        _totalValue = _totalValue.add(value);

        IDDP(_ddp).deposit(tokenId, value, maturityEnds);
    }

    function hasToken(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }

    function burn(uint256 tokenId) external override {
        require(
            hasRole(TokenAccessRoles.burner(), _msgSender()),
            "user is not allowed to burn tokens"
        );

        uint256 value = _bondInfo[tokenId].value;
        delete _bondInfo[tokenId];
        _totalValue.sub(value);

        _burn(tokenId);
    }

    // approval functions must be prohibited
    function approve(address, uint256) public override {
        revert("method is not supported");
    }

    function getApproved(uint256) public view override returns (address) {
        revert("method is not supported");
    }

    function setApprovalForAll(address, bool) public override {
        revert("method is not supported");
    }

    function isApprovedForAll(address, address)
        public
        view
        override
        returns (bool)
    {
        revert("method is not supported");
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override
    {
        _safeTransferFrom(
            _msgSender(),
            from,
            to,
            tokenId,
            "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId) public override
    {
        _safeTransferFrom(
            _msgSender(),
            from,
            to,
            tokenId,
            "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override
    {
        _safeTransferFrom(
            _msgSender(),
            from,
            to,
            tokenId,
            _data);
    }

    function _safeTransferFrom(
        address sender,
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private
    {
        require(
            hasRole(TokenAccessRoles.transferer(), sender),
            "user is not allowed to transfer tokens"
        );
        require(
            AllowList(_allowList).isAllowedAccount(to),
            "user is not allowed to receive tokens"
        );

        _safeTransfer(
            from,
            to,
            tokenId,
            _data);

        if (sender != _sat) {
            SecurityAssetToken(_sat)
            .safeTransferFrom(
                from,
                to,
                tokenId,
                _data);
        }
    }
}
