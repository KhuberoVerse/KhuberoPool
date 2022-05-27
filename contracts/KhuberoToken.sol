// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

//import "hardhat/console.sol";

contract KhuberoToken is ERC20, Pausable, Ownable {

    bytes32 public merkleRoot;
    constructor() ERC20("KhuberoToken", "KBR") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount, bytes32[] memory _merkleProof) public payable {
        require(MerkleProof.verify(_merkleProof, getMerkleRoot(), keccak256(abi.encodePacked(msg.sender))), "Only whitelisted mint");
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function setMerkleRoot(bytes32 root) onlyOwner external {
        merkleRoot = root;
    }

    function getMerkleRoot() public view returns (bytes32) {
        return merkleRoot;
    }

    function ethBalance(address _addr) public view returns (uint) {
        return address(_addr).balance;
    }

}