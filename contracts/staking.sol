// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IGHST {
    function stakeGhst(uint256 _ghstValue) external;

    function withdrawGhstStake(uint256 _ghstValue) external;

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(address _spender, uint256 _value)
        external
        returns (bool success);

    function transfer(address _to, uint256 _value)
        external
        returns (bool success);

    function balanceOf(address _owner) external view returns (uint256 balance);
}

interface IGltrStaking {
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function harvest(uint256 _pid) external;
}

interface IWrapper {
    function enterWithUnderlying(uint256 assets)
        external
        returns (uint256 shares);

    function leaveToUnderlying(uint256 shares)
        external
        returns (uint256 assets);
}

interface IAavegotchiGameFacet {
    function isPetOperatorForAll(address _owner, address _operator)
        external
        view
        returns (bool approved_);
}

contract Staking is Ownable {
    address diamond = 0x86935F11C86623deC8a25696E1C19a8659CbF95d;
    address ghst = 0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7;
    address wapGhst = 0x73958d46B7aA2bc94926d8a215Fa560A5CdCA3eA;
    address gltrStaking = 0x1fE64677Ab1397e20A1211AFae2758570fEa1B8c;
    address gltr = 0x3801C3B3B5c98F88a9c9005966AA96aa440B9Afc;
    address petter = 0x290000C417a1DE505eb08b7E32b3e8dA878D194E;

    uint256 private constant STAKING_AMOUNT = 99 * 10**18;
    uint256 private constant FEES = 10**18;
    uint256 constant MAX_INT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    address[] private users;
    mapping(address => uint256) private usersToIndex;

    mapping(address => uint256) private ghstBalance;
    mapping(address => uint256) private sharesBalance;

    mapping(address => bool) private isApproved;

    constructor() {
        // This contract approves the wapGhst contract to move GHST
        IERC20(ghst).approve(wapGhst, MAX_INT);

        // This contract approves the deposit contract to move wapGhst
        IERC20(wapGhst).approve(gltrStaking, MAX_INT);

        // Mandatory, index 0 cannot be empty
        _addUser(0x86935F11C86623deC8a25696E1C19a8659CbF95d);

        // Add owner as approved
        isApproved[msg.sender] = true;
    }

    modifier onlyApproved() {
        require(
            msg.sender == owner() || isApproved[msg.sender],
            "Staking: Not Approved"
        );
        _;
    }

    function getIsSignedUp(address _address) external view returns (bool) {
        return usersToIndex[_address] > 0;
    }

    function hasApprovedGotchiInteraction(address _account)
        public
        view
        returns (bool)
    {
        return
            IAavegotchiGameFacet(diamond).isPetOperatorForAll(_account, petter);
    }

    function getIsApproved(address _address) external view returns (bool) {
        return isApproved[_address];
    }

    function getUsers() external view returns (address[] memory) {
        return users;
    }

    function getUsersCount() external view returns (uint256) {
        return users.length - 1;
    }

    function getUsersIndexed(uint256 _pointer, uint256 _amount)
        external
        view
        returns (address[] memory)
    {
        address[] memory addresses = new address[](_amount);
        for (uint256 i = 0; i < _amount; i++) {
            uint256 pointer = _pointer + i;
            if (pointer > users.length) break;
            addresses[i] = users[pointer];
        }
        return addresses;
    }

    function getUsersToIndex(address _user) external view returns (uint256) {
        return usersToIndex[_user];
    }

    function getUserGhstBalance(address _user) external view returns (uint256) {
        return ghstBalance[_user];
    }

    function getUserShares(address _user) external view returns (uint256) {
        return sharesBalance[_user];
    }

    function getContractGltr() external view returns (uint256) {
        return IERC20(gltr).balanceOf(address(this));
    }

    function getContractGhst() external view returns (uint256) {
        return IERC20(ghst).balanceOf(address(this));
    }

    function signUp() external {
        // Make sure user is not already staking
        require(ghstBalance[msg.sender] == 0, "Staking: Already staking");

        // Get the ghst from the account to the contract
        IGHST(ghst).transferFrom(msg.sender, address(this), STAKING_AMOUNT);

        // Removes 1 GHST as Fees
        uint256 stakingAmount = STAKING_AMOUNT - FEES;

        // wrap the GHST
        uint256 shares = IWrapper(wapGhst).enterWithUnderlying(stakingAmount);

        // deposit wrapped ghst
        IGltrStaking(gltrStaking).deposit(0, shares);

        // Update the Balance of the user
        ghstBalance[msg.sender] = stakingAmount;
        sharesBalance[msg.sender] = shares;

        // Add to the user array
        _addUser(msg.sender);
    }

    function leave() external {
        // Check if the account has ghst staked
        require(ghstBalance[msg.sender] > 0, "Staking: Nothing to unstake");

        // Save balance of the user
        uint256 tempBalance = ghstBalance[msg.sender];
        uint256 tempShares = sharesBalance[msg.sender];

        // Update the balances of the user
        ghstBalance[msg.sender] = 0;
        sharesBalance[msg.sender] = 0;

        // Withdraw wapGhst
        IGltrStaking(gltrStaking).withdraw(0, tempShares);

        // Unwrap ghst
        IWrapper(wapGhst).leaveToUnderlying(tempShares);

        // Send back the ghst to the user
        IGHST(ghst).transfer(msg.sender, tempBalance);

        // Remove from user array
        _removeUser(msg.sender);
    }

    /**
        Internal 
    */

    function _addUser(address _newUser) private {
        // No need to add twice the same account
        require(usersToIndex[_newUser] == 0, "staking: user already added");

        // Get the index where the new user is in the array (= last position)
        usersToIndex[_newUser] = users.length;

        // Add the user in the array
        users.push(_newUser);
    }

    function _removeUser(address _addressLeaver) private {
        // Cant remove an account that is not a user
        require(
            usersToIndex[_addressLeaver] != 0,
            "Staking: user already removed"
        );

        // Get the index of the leaver
        uint256 _indexLeaver = usersToIndex[_addressLeaver];

        // Get last index
        uint256 lastElementIndex = users.length - 1;

        // Get Last address in array
        address lastAddressInArray = users[lastElementIndex];

        // Move the last address in the position of the leaver
        users[_indexLeaver] = users[lastElementIndex];

        // Change the moved address' index to the new one
        usersToIndex[lastAddressInArray] = _indexLeaver;

        // Remove last entry in the array and reduce length
        users.pop();
        usersToIndex[_addressLeaver] = 0;
    }

    /**
        Admin 
    */

    /**
     * @dev GLTR is claimed when a user leaves
     */
    function claimGltr() external {
        IGltrStaking(gltrStaking).harvest(0);
    }

    function withdrawGltr(address _tokenReceiver) external onlyApproved {
        uint256 amount = IERC20(gltr).balanceOf(address(this));
        IERC20(gltr).transfer(_tokenReceiver, amount);
    }

    /**
     * @notice Can't withdraw user fund with this function
     * User funds are, at all time, staked in the Aavegotchi contract
     */
    function withdrawGhst(address _tokenReceiver) external onlyApproved {
        uint256 amount = IERC20(ghst).balanceOf(address(this));
        IERC20(ghst).transfer(_tokenReceiver, amount);
    }

    function withdrawGltrAndGhst(address _tokenReceiver) external onlyApproved {
        IGltrStaking(gltrStaking).harvest(0);
        uint256 amountGltr = IERC20(gltr).balanceOf(address(this));
        if (amountGltr > 0) IERC20(gltr).transfer(_tokenReceiver, amountGltr);

        uint256 amountGhst = IERC20(ghst).balanceOf(address(this));
        if (amountGhst > 0) IERC20(ghst).transfer(_tokenReceiver, amountGhst);
    }

    function setIsApproved(address _address, bool _isApproved)
        external
        onlyOwner
    {
        isApproved[_address] = _isApproved;
    }
}
