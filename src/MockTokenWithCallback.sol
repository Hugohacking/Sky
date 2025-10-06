// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

interface IChief {
    function etch(address[] calldata yays) external returns (bytes32);
    function vote(address[] calldata yays) external returns (bytes32);
    function deposits(address usr) external view returns (uint256);
}

contract MockTokenWithCallback {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    string public name = "MockTokenWithCallback";
    string public symbol = "MTWC";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    address public chief;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ReentrantCallback(address who, uint256 wad, uint256 depositsBefore);

    constructor(address chief_) {
        chief = chief_;
        _mint(msg.sender, 100 ether);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "MTWC/insufficient-balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "MTWC/insufficient-balance");
        require(allowance[from][msg.sender] >= amount, "MTWC/insufficient-allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        // Callback réentrant inoffensif
        uint256 depositsBefore = IChief(chief).deposits(from);
        emit ReentrantCallback(from, amount, depositsBefore);
        // Appel inoffensif sur Chief (etch ou vote)
        address[] memory yays = new address[](0);
        IChief(chief).etch(yays);
        return true;
    }
}
