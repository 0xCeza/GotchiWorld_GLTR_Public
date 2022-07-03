// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**

TODO 

- check if/when claimGltr reverts
- Claim interest from AAVE?
- Manage Bot that will
1. Claim & Withdraw GLTR => FROM SWAPPER CONTRACT
2. Withdraw GHST (include fees) => FROM SWAPPER CONTRACT
3. Call private swapper contract (use quickswap)

in SWAPPER :
function swapToMaticAndUsdc() external onlySwapperBotOrOwner {
    IStaking(stakingAddress).withdrawGltrAndGhst(address(this));
    _swapGltrToGhst(gltrAmount);
    _swapGhstToMatic(ghstAmount / 3);
    _swapGhstToUsdc(ghstAmount / 3);
    IERC20(Matic).transfer(petter, allBalance);
    IERC20(USDC).transfer(owner, allBalance);
    IERC20(GHST).transfer(owner, allBalance);
}

 */

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

contract Staking is Ownable {
    address diamond = 0x86935F11C86623deC8a25696E1C19a8659CbF95d;
    address ghst = 0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7;
    address wapGhst = 0x73958d46B7aA2bc94926d8a215Fa560A5CdCA3eA;
    address gltrStaking = 0x1fE64677Ab1397e20A1211AFae2758570fEa1B8c;
    address gltr = 0x3801C3B3B5c98F88a9c9005966AA96aa440B9Afc;
    address autolending;

    uint256 private constant STAKING_AMOUNT = 99 * 10**18;
    uint256 private constant FEES = 10**18;
    uint256 constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    address[] private users;
    mapping(address => uint256) public usersToIndex;

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

    function getUsers() external view returns (address[] memory) {
        return users;
    }

    function getUserBalance(address _user) external view returns (uint256) {
        return ghstBalance[_user];
    }

    function getUserShares(address _user) external view returns (uint256) {
        return sharesBalance[_user];
    }

    function signUp() external {
        // Make sure user is not already staking
        require(ghstBalance[msg.sender] == 0, "Staking: Already staking");

        // Get the ghst from the account to the contract
        IGHST(ghst).transferFrom(msg.sender, address(this), STAKING_AMOUNT);

        uint256 stakingAmount = STAKING_AMOUNT - FEES;

        // wrap the GHST
        uint256 shares = IWrapper(wapGhst).enterWithUnderlying(stakingAmount);

        // deposit wrapped ghst
        IGltrStaking(gltrStaking).deposit(0, shares);

        // Update the Balance of the msgsender
        ghstBalance[msg.sender] = stakingAmount;
        sharesBalance[msg.sender] = shares;

        // Add to the user array
        _addUser(msg.sender);
    }

    function leave() external {
        // Check if the account has enough ghst staked
        require(ghstBalance[msg.sender] > 0, "Staking: Can't unstake");

        // Save balance of msgsender
        uint256 tempBalance = ghstBalance[msg.sender];
        uint256 tempShares = sharesBalance[msg.sender];

        // Update the balances of msgsender
        ghstBalance[msg.sender] = 0;
        sharesBalance[msg.sender] = 0;

        // Undeposit wapGhst
        IGltrStaking(gltrStaking).withdraw(0, tempShares);

        // unwrap ghst
        IWrapper(wapGhst).leaveToUnderlying(tempShares);

        // Send back the ghst to the msgsender
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

        // Get the index where the new user is in the array
        usersToIndex[_newUser] = users.length;

        // Push the data in the array
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
    function withdrawGltr(address _tokenReceiver) external onlyApproved {
        IGltrStaking(gltrStaking).harvest(0); // todo check if/when reverts
        uint256 amount = IERC20(gltr).balanceOf(address(this));
        IERC20(gltr).transfer(_tokenReceiver, amount);
    }

    function withdrawGhst(address _tokenReceiver) external onlyApproved {
        uint256 amount = IERC20(ghst).balanceOf(address(this));
        IERC20(ghst).transfer(_tokenReceiver, amount);
    }

    function withdrawGltrAndGhst(address _tokenReceiver) external onlyApproved {
        IGltrStaking(gltrStaking).harvest(0); // todo check if/when reverts
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
