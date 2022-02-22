// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// We first import some OpenZeppelin Contracts.
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {StringUtils} from "./libraries/StringUtils.sol";
// We import another help function
import {Base64} from "./libraries/Base64.sol";

import "hardhat/console.sol";

// We inherit the contract we imported. This means we'll have access
// to the inherited contract's methods.
contract Domains is ERC721URIStorage {
    // Magic given to us by OpenZeppelin to help us keep track of tokenIds.
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    error Unauthorized();
    error AlreadyRegistered();
    error InvalidName(string name);

    string public tld;

    // We'll be storing our NFT images on chain as SVGs
    string svgPartOne =
        '<svg xmlns="http://www.w3.org/2000/svg" width="270" height="270" fill="none"><path fill="url(#a)" d="M0 0h270v270H0z"/><defs><filter id="b" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="270" width="270"><feDropShadow dx="0" dy="1" stdDeviation="2" flood-opacity=".225" width="200%" height="200%"/></filter></defs><path d="M26.957 27.48a11 11 0 0 0-14.735 16.298v.002a11 11 0 1 0 14.736-16.3Zm-6.58 7.013a8.997 8.997 0 0 0-4.621-6.423 9.081 9.081 0 0 1 10.826 1.807 6.979 6.979 0 0 1-6.205 4.616Zm-8.345 5.694a9.015 9.015 0 0 1 1.828-10.754c6.144 2.078 6.143 11.036.016 13.149a8.543 8.543 0 0 1-1.844-2.395Zm14.332 2.177a9.015 9.015 0 0 1-10.624 1.56 8.893 8.893 0 0 0 4.747-7.445 8.898 8.898 0 0 0 7.437-4.74 9.015 9.015 0 0 1-1.56 10.625Z" fill="#fff"/><path d="M44 11a16.907 16.907 0 0 0-15.563 10.253C17.323 14.721 2.863 23.085 3 36c.274 18.417 25.013 23.545 32.59 6.77C46.693 49.228 61.133 40.93 61 28a17.08 17.08 0 0 0-17-17ZM30.606 46.606C21.226 56.02 4.977 49.286 5 36c-.115-11.864 13.544-19.14 23.325-12.483a14.951 14.951 0 0 1 6.511 10.375 15.016 15.016 0 0 1-4.23 12.714Zm5.468-22.87a8.935 8.935 0 0 0 7.44 4.751 8.91 8.91 0 0 0 4.746 7.437 9.01 9.01 0 0 1-11.46-2.54 16.85 16.85 0 0 0-1.784-5.369 8.949 8.949 0 0 1 1.058-4.279Zm1.553-2.09a9.04 9.04 0 0 1 12.94.214c-2.019 6.106-11.055 6.153-13.149.016.07-.076.135-.157.21-.23Zm13.618 11.676a7.46 7.46 0 0 1-1.121 1.26 6.978 6.978 0 0 1-4.617-6.205 9.02 9.02 0 0 0 6.423-4.62 9.1 9.1 0 0 1-.685 9.565Zm3.361 5.284a15.02 15.02 0 0 1-18.313 2.26 18.379 18.379 0 0 0 .696-4.395c10.448 8.223 23.714-5.049 15.491-15.473a11.024 11.024 0 0 0-16.258-.776h-.001a11.105 11.105 0 0 0-2.901 5.224 17.15 17.15 0 0 0-3.198-3.1c3.761-9.825 17.202-12.523 24.484-4.952a15.07 15.07 0 0 1 0 21.212Z" fill="#fff"/><path d="M23 38a1 1 0 0 0 0 2 1 1 0 0 0 0-2Zm18-6a1 1 0 0 0 0-2 1 1 0 0 0 0 2Z" fill="#fff"/><defs><linearGradient id="a" x1="0" y1="0" x2="270" y2="270" gradientUnits="userSpaceOnUse"><stop stop-color="#cb5eee"/><stop offset="1" stop-color="#0cd7e4" stop-opacity=".99"/></linearGradient></defs><text x="32.5" y="231" font-size="27" fill="#fff" filter="url(#b)" font-family="Plus Jakarta Sans,DejaVu Sans,Noto Color Emoji,Apple Color Emoji,sans-serif" font-weight="bold">';
    string svgPartTwo = "</text></svg>";

    mapping(string => address) public domains;
    mapping(string => string) public records;
    mapping(uint256 => string) public names;
    address payable public owner;

    constructor(string memory _tld)
        payable
        ERC721("Sushi Name Service", "SNS")
    {
        owner = payable(msg.sender);
        tld = _tld;
        console.log("%s name service deployed", _tld);
    }

    function register(string calldata name) public payable {
        if (domains[name] != address(0)) revert AlreadyRegistered();
        if (!valid(name)) revert InvalidName(name);

        uint256 _price = price(name);
        require(msg.value >= _price, "Not enough Matic paid");

        // Combine the name passed into the function  with the TLD
        string memory _name = string(abi.encodePacked(name, ".", tld));
        // Create the SVG (image) for the NFT with the name
        string memory finalSvg = string(
            abi.encodePacked(svgPartOne, _name, svgPartTwo)
        );
        uint256 newRecordId = _tokenIds.current();
        uint256 length = StringUtils.strlen(name);
        string memory strLen = Strings.toString(length);

        console.log(
            "Registering %s.%s on the contract with tokenID %d",
            name,
            tld,
            newRecordId
        );

        // Create the JSON metadata of our NFT. We do this by combining strings and encoding as base64
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        _name,
                        '", "description": "A domain on the Sushi name service", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(finalSvg)),
                        '","length":"',
                        strLen,
                        '"}'
                    )
                )
            )
        );

        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        console.log(
            "\n--------------------------------------------------------"
        );
        console.log("Final tokenURI", finalTokenUri);
        console.log(
            "--------------------------------------------------------\n"
        );

        _safeMint(msg.sender, newRecordId);
        _setTokenURI(newRecordId, finalTokenUri);
        domains[name] = msg.sender;

        names[newRecordId] = name;
        _tokenIds.increment();
    }

    // We still need the price, getAddress, setRecord and getRecord functions, they just don't change
    function price(string calldata name) public pure returns (uint256) {
        uint256 len = StringUtils.strlen(name);
        require(len > 0);
        if (len == 3) {
            return 1 * 10**17; // 0.1 MATIC = 5 000 000 000 000 000 000 (18 decimals). We're going with 0.5 Matic cause the faucets don't give a lot
        } else if (len == 4) {
            return 0.3 * 10**17; // To charge smaller amounts, reduce the decimals. This is 0.03
        } else {
            return 0.1 * 10**17;
        }
    }

    function valid(string calldata name) public pure returns (bool) {
        return StringUtils.strlen(name) >= 3 && StringUtils.strlen(name) <= 10;
    }

    function getAddress(string calldata name) public view returns (address) {
        // Check that the owner is the transaction sender
        return domains[name];
    }

    function setRecord(string calldata name, string calldata record) public {
        // Check that the owner is the transaction sender
        if (domains[name] != msg.sender) revert Unauthorized();
        records[name] = record;
    }

    function getRecord(string calldata name)
        public
        view
        returns (string memory)
    {
        return records[name];
    }

    function getAllNames() public view returns (string[] memory) {
        console.log("Getting all names from contract");
        string[] memory allNames = new string[](_tokenIds.current());
        for (uint256 i = 0; i < _tokenIds.current(); i++) {
            allNames[i] = names[i];
            console.log("Name for token %d is %s", i, allNames[i]);
        }

        return allNames;
    }

    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == owner;
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Failed to withdraw Matic");
    }
}
