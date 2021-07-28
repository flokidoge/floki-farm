// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libs/IPancakeswapFarm.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";

interface IWBNB is IBEP20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

contract Strat is Ownable, ReentrancyGuard, Pausable {
    // Maximises yields in pancakeswap

    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    address public farmContractAddress; // address of farm
    address public chefAddress; // masterchef contract

    event SetChefAddress(address _chefAddress);
    event SetFarmAddress(address _chefAddress);

    modifier onlyChef() {
        require(msg.sender == chefAddress, "!chef");
        _;
    }

    function setFarm(address _farmAddress) public onlyOwner {
        farmContractAddress = _farmAddress;
        emit SetFarmAddress(farmContractAddress);
    }

    function setChef(address _chefAddress) public onlyOwner {
        chefAddress = _chefAddress;
        emit SetChefAddress(chefAddress);
    }

    // Receives new deposits from user
    function deposit(
        address _tokenAddress,
        uint256 _farmPid,
        uint256 _wantAmt
    ) public nonReentrant whenNotPaused onlyChef returns (uint256) {
        uint256 prevAmount = IBEP20(_tokenAddress).balanceOf(address(this));
        IBEP20(_tokenAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );
        uint256 afterAmount = IBEP20(_tokenAddress).balanceOf(address(this));
        _wantAmt = afterAmount.sub(prevAmount);
        IBEP20(_tokenAddress).approve(farmContractAddress, _wantAmt);
        if (_farmPid == 0) {
            IPancakeswapFarm(farmContractAddress).enterStaking(_wantAmt); // Just for CAKE staking, we dont use deposit()
        } else {
            IPancakeswapFarm(farmContractAddress).deposit(_farmPid, _wantAmt);
        }

        return _wantAmt;
    }

    function withdraw(
        address _tokenAddress,
        uint256 _farmPid,
        uint256 _wantAmt
    ) public nonReentrant onlyChef returns (uint256) {
        require(_wantAmt > 0, "_wantAmt <= 0");

        uint256 prevAmount = IBEP20(_tokenAddress).balanceOf(address(this));
        if (_farmPid == 0) {
            IPancakeswapFarm(farmContractAddress).leaveStaking(_wantAmt); // Just for CAKE staking, we dont use deposit()
        } else {
            IPancakeswapFarm(farmContractAddress).withdraw(_farmPid, _wantAmt);
        }
        uint256 afterAmount = IBEP20(_tokenAddress).balanceOf(address(this));
        _wantAmt = afterAmount.sub(prevAmount);
        IBEP20(_tokenAddress).safeTransfer(address(msg.sender), _wantAmt);
        return _wantAmt;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function emergencyWithdraw(uint256 _farmPid, uint256 _wantAmt)
        public
        onlyOwner
    {
        if (_farmPid == 0) {
            IPancakeswapFarm(farmContractAddress).leaveStaking(_wantAmt); // Just for CAKE staking, we dont use deposit()
        } else {
            IPancakeswapFarm(farmContractAddress).withdraw(_farmPid, _wantAmt);
        }
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public onlyOwner {
        IBEP20(_token).safeTransfer(_to, _amount);
    }
}
