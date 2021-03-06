// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./libs/IFlokiReferral.sol";
import "./libs/IPancakeswapFarm.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./FlokiToken.sol";
import "./Strat.sol";

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once FLOKI is sufficiently
// distributed and the community can show to govern itself.

contract MasterChef is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardLockedUp; // Reward locked up.
        uint256 nextHarvestUntil; // When can the user harvest again.
        //
        // We do some fancy math here. Basically, any point in time, the amount of FLOKIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accFlokiPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accFlokiPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. FLOKIs to distribute per block.
        uint256 lastRewardBlock; // Last block number that FLOKIs distribution occurs.
        uint256 accFlokiPerShare; // Accumulated FLOKIs per share, times 1e12. See below.
        uint16 depositFeeBP; // Deposit fee in basis points
        uint16 transactionFeeBP; // Transaction fee in basis points
        uint256 harvestInterval; // Harvest interval in seconds
        uint256 farmPid; // the pid of the third party farm
        bool enableStrat; // enable start
    }

    // The FLOKI TOKEN!
    FlokiToken public floki;
    Strat public strat;
    IPancakeswapFarm public ofarm;
    // Dev address.
    address public devAddress;
    // Deposit Fee address
    address public feeAddress;
    // FLOKI tokens created per block.
    uint256 public flokiPerBlock;
    // Bonus muliplier for early floki makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Max harvest interval: 14 days.
    uint256 public constant MAXIMUM_HARVEST_INTERVAL = 14 days;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when floki mining starts.
    uint256 public startBlock;
    // Total locked up rewards
    uint256 public totalLockedUpRewards;

    // Floki referral contract address.
    IFlokiReferral public flokiReferral;
    // Referral commission rate in basis points.
    uint16 public referralCommissionRate = 100;
    // Max referral commission rate: 10%.
    uint16 public constant MAXIMUM_REFERRAL_COMMISSION_RATE = 1000;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event EmissionRateUpdated(
        address indexed caller,
        uint256 previousAmount,
        uint256 newAmount
    );
    event ReferralCommissionPaid(
        address indexed user,
        address indexed referrer,
        uint256 commissionAmount
    );
    event RewardLockedUp(
        address indexed user,
        uint256 indexed pid,
        uint256 amountLockedUp
    );

    constructor(
        FlokiToken _floki,
        uint256 _startBlock,
        uint256 _flokiPerBlock
    ) public {
        floki = _floki;
        startBlock = _startBlock;
        flokiPerBlock = _flokiPerBlock;

        devAddress = msg.sender;
        feeAddress = msg.sender;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IBEP20 _lpToken,
        uint16 _depositFeeBP,
        uint16 _transactionFeeBP,
        uint256 _harvestInterval,
        uint256 _farmPid,
        bool _enableStrat,
        bool _withUpdate
    ) public onlyOwner {
        require(
            _depositFeeBP <= 10000,
            "add: invalid deposit fee basis points"
        );
        require(
            _harvestInterval <= MAXIMUM_HARVEST_INTERVAL,
            "add: invalid harvest interval"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accFlokiPerShare: 0,
                depositFeeBP: _depositFeeBP,
                transactionFeeBP: _transactionFeeBP,
                harvestInterval: _harvestInterval,
                farmPid: _farmPid,
                enableStrat: _enableStrat
            })
        );
    }

    // Update the given pool's FLOKI allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        uint16 _transactionFeeBP,
        uint256 _harvestInterval,
        uint256 _farmPid,
        bool _enableStrat,
        bool _withUpdate
    ) public onlyOwner {
        require(
            _depositFeeBP <= 10000,
            "set: invalid deposit fee basis points"
        );
        require(
            _transactionFeeBP <= 10000,
            "set: invalid transaction fee basis points"
        );
        require(
            _harvestInterval <= MAXIMUM_HARVEST_INTERVAL,
            "set: invalid harvest interval"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
        poolInfo[_pid].transactionFeeBP = _transactionFeeBP;
        poolInfo[_pid].harvestInterval = _harvestInterval;
        poolInfo[_pid].farmPid = _farmPid;
        poolInfo[_pid].enableStrat = _enableStrat;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        pure
        returns (uint256)
    {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function getLpSupply(uint256 _pid) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lpSupply = 0;
        if (pool.enableStrat) {
            lpSupply = ofarm.userInfo(pool.farmPid, address(strat));
        } else {
            lpSupply = pool.lpToken.balanceOf(address(this));
        }
        return lpSupply;
    }

    // View function to see pending FLOKIs on frontend.
    function pendingFloki(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accFlokiPerShare = pool.accFlokiPerShare;
        uint256 lpSupply = getLpSupply(_pid);
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 flokiReward = multiplier
                .mul(flokiPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accFlokiPerShare = accFlokiPerShare.add(
                flokiReward.mul(1e12).div(lpSupply)
            );
        }
        uint256 pending = user.amount.mul(accFlokiPerShare).div(1e12).sub(
            user.rewardDebt
        );
        return pending.add(user.rewardLockedUp);
    }

    // View function to see if user can harvest Flokis.
    function canHarvest(uint256 _pid, address _user)
        public
        view
        returns (bool)
    {
        UserInfo storage user = userInfo[_pid][_user];
        return block.timestamp >= user.nextHarvestUntil;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = getLpSupply(_pid);
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 flokiReward = multiplier
            .mul(flokiPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        // floki.mint(devAddress, flokiReward.div(10));
        // floki.mint(address(this), flokiReward);
        floki.mintWithDevReward(address(this), devAddress, flokiReward);
        pool.accFlokiPerShare = pool.accFlokiPerShare.add(
            flokiReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for FLOKI allocation.
    function deposit(
        uint256 _pid,
        uint256 _amount,
        address _referrer
    ) public nonReentrant whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (
            _amount > 0 &&
            address(flokiReferral) != address(0) &&
            _referrer != address(0) &&
            _referrer != msg.sender
        ) {
            flokiReferral.recordReferral(msg.sender, _referrer);
        }
        payOrLockupPendingFloki(_pid);
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            if (pool.transactionFeeBP > 0) {
                uint256 transferTax = _amount.mul(pool.transactionFeeBP).div(
                    10000
                );
                _amount = _amount.sub(transferTax);
            }
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                _amount = _amount.sub(depositFee);
            }
            if (address(strat) != address(0) && pool.enableStrat) {
                pool.lpToken.approve(address(strat), _amount);
                strat.deposit(address(pool.lpToken), pool.farmPid, _amount);
                if (pool.transactionFeeBP > 0) {
                    _amount = _amount.mul(10000 - pool.transactionFeeBP).div(
                        10000
                    );
                    _amount = _amount.mul(10000 - pool.transactionFeeBP).div(
                        10000
                    );
                }
            }
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accFlokiPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        payOrLockupPendingFloki(_pid);
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            if (address(strat) != address(0) && pool.enableStrat) {
                strat.withdraw(address(pool.lpToken), pool.farmPid, _amount);
                if (pool.transactionFeeBP > 0) {
                    _amount = _amount.mul(10000 - pool.transactionFeeBP).div(
                        10000
                    );
                    _amount = _amount.mul(10000 - pool.transactionFeeBP).div(
                        10000
                    );
                }
            }
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accFlokiPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardLockedUp = 0;
        user.nextHarvestUntil = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Pay or lockup pending FLOKIs.
    function payOrLockupPendingFloki(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.nextHarvestUntil == 0) {
            user.nextHarvestUntil = block.timestamp.add(pool.harvestInterval);
        }

        uint256 pending = user.amount.mul(pool.accFlokiPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (canHarvest(_pid, msg.sender)) {
            if (pending > 0 || user.rewardLockedUp > 0) {
                uint256 totalRewards = pending.add(user.rewardLockedUp);

                // reset lockup
                totalLockedUpRewards = totalLockedUpRewards.sub(
                    user.rewardLockedUp
                );
                user.rewardLockedUp = 0;
                user.nextHarvestUntil = block.timestamp.add(
                    pool.harvestInterval
                );

                // send rewards
                uint256 referalRewards = payReferralCommission(
                    msg.sender,
                    totalRewards
                );
                safeFlokiTransfer(msg.sender, totalRewards.sub(referalRewards));
            }
        } else if (pending > 0) {
            user.rewardLockedUp = user.rewardLockedUp.add(pending);
            totalLockedUpRewards = totalLockedUpRewards.add(pending);
            emit RewardLockedUp(msg.sender, _pid, pending);
        }
    }

    // Safe Floki transfer function, just in case if rounding error causes pool to not have enough FLOKIs.
    function safeFlokiTransfer(address _to, uint256 _amount) internal {
        uint256 flokiBal = floki.balanceOf(address(this));
        if (_amount > flokiBal) {
            floki.transfer(_to, flokiBal);
        } else {
            floki.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function setDevAddress(address _devAddress) public {
        require(msg.sender == devAddress, "setDevAddress: FORBIDDEN");
        require(_devAddress != address(0), "setDevAddress: ZERO");
        devAddress = _devAddress;
    }

    function setFeeAddress(address _feeAddress) public {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        require(_feeAddress != address(0), "setFeeAddress: ZERO");
        feeAddress = _feeAddress;
    }

    function updateEmissionRate(uint256 _flokiPerBlock) public onlyOwner {
        massUpdatePools();
        emit EmissionRateUpdated(msg.sender, flokiPerBlock, _flokiPerBlock);
        flokiPerBlock = _flokiPerBlock;
    }

    // Update the floki referral contract address by the owner
    function setFlokiReferral(IFlokiReferral _flokiReferral) public onlyOwner {
        flokiReferral = _flokiReferral;
    }

    function setOfarm(IPancakeswapFarm _ofarm) public onlyOwner {
        ofarm = _ofarm;
    }

    // Update the floki referral contract address by the owner
    function setStrat(Strat _strat) public onlyOwner {
        strat = _strat;
    }

    function setFloki(FlokiToken _flokiToken) public onlyOwner {
        floki = _flokiToken;
    }

    function transferFlokiOwnership(address _newOwner) public onlyOwner {
        floki.transferOwnership(_newOwner);
    }

    // Update referral commission rate by the owner
    function setReferralCommissionRate(uint16 _referralCommissionRate)
        public
        onlyOwner
    {
        require(
            _referralCommissionRate <= MAXIMUM_REFERRAL_COMMISSION_RATE,
            "setReferralCommissionRate: invalid referral commission rate basis points"
        );
        referralCommissionRate = _referralCommissionRate;
    }

    // Pay referral commission to the referrer who referred this user.
    function payReferralCommission(address _user, uint256 _pending)
        internal
        returns (uint256)
    {
        if (
            address(flokiReferral) != address(0) && referralCommissionRate > 0
        ) {
            address referrer = flokiReferral.getReferrer(_user);
            uint256 commissionAmount = _pending.mul(referralCommissionRate).div(
                10000
            );

            if (referrer != address(0) && commissionAmount > 0) {
                // floki.mint(referrer, commissionAmount);
                safeFlokiTransfer(referrer, commissionAmount);
                flokiReferral.recordReferralCommission(
                    referrer,
                    commissionAmount
                );
                emit ReferralCommissionPaid(_user, referrer, commissionAmount);
                return commissionAmount;
            }
        }
        return 0;
    }
}
