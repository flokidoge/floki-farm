// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlokiLocker is Ownable {
    using SafeBEP20 for IBEP20;
    uint256 public endBlock = 0;
    bool public closed = false;

    event Unlocked(address indexed token, address indexed recipient, uint256 amount);

    function setEndBlock(uint256 _endBlock) public onlyOwner {
        require(closed == false, "FlokiLocker::setEndBlock: closed");
        endBlock = _endBlock;
    }

    function setClose() public onlyOwner {
        closed = true;
    }

    function unlock(IBEP20 _token, address _recipient) public onlyOwner {
        require(_recipient != address(0), "FlokiLocker::unlock: ZERO address.");
        require(block.number > endBlock, "FlokiLocker::unlock: Before end");

        uint256 amount = _token.balanceOf(address(this));
        _token.safeTransfer(_recipient, amount);
        emit Unlocked(address(_token), _recipient, amount);
    }
}
