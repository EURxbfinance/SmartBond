pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./templates/Initializable.sol";


/**
 * @title StakingManager
 * @dev Staking manager contract
 */
contract StakingManager is Initializable {
    using SafeMath for uint256;

    uint256 constant private XBG_AMOUNT = 12000 ether;
    uint256[7] private DAILY_XBG_REWARD = [
        999900 finney, // first day - 33.33%
        585000 finney, // second day - 19.50%
        414900 finney, // third day - 13.83%
        321600 finney, // 4th day - 10.72%
        263100 finney, // 5th day - 8,77%
        222600 finney, // 6th day - 7,42%
        192900 finney]; // 7th day - 6,43%

    struct Accumulator {
        uint256 lpTotalAmount;
        uint256 xbgTotalReward;
    }

    event StakerAdded(address user, address pool, uint256 day, uint256 amount);
    event StakerHasClaimedReward(address user, uint256[4] lpTokens, uint256 xbgTokens);

    /// all available pools
    address[4] private _pools;

    /// pool address => status
    mapping(address => bool) private _allowListOfPools;

    /// user address => pool address => daily lp balance
    mapping(address => mapping(address => uint256[7])) private _stakes;

    /// pool address => total LP tokens value which was added per day and daily reward
    mapping(address => Accumulator[7]) private _dailyAccumulator;

    IERC20 private _tokenXbg;

    uint256 private _startTime;

    constructor(
        address xbg,
        uint256 startTime
    ) public {
        _tokenXbg = IERC20(xbg);
        _startTime = startTime;
    }

    /**
     * @dev add all pools address for staking
     */
    function configure(address[4] calldata pools) external initializer {
        _tokenXbg.transferFrom(_msgSender(), address(this), XBG_AMOUNT);

        for (uint i = 0; i < 4; ++i) {
            address pool = pools[i];
            _allowListOfPools[pool] = true;
            _pools[i] = pools[i];
            for (uint j = 0; j < 7; ++j) {
                _dailyAccumulator[pool][j].xbgTotalReward = DAILY_XBG_REWARD[j];
            }
        }
    }

    /**
     * @return start time
     */
    function startTime() external view returns (uint256) {
        return _startTime;
    }

    /**
     * @return end time
     */
    function endTime() external view returns (uint256) {
        return _startTime + 7 days;
    }

    /**
     * @return day number from startTime
     */
    function currentDay() external view returns (uint256) {
        if (block.timestamp < _startTime) {
            return 0;
        }
        uint256 day = (block.timestamp - _startTime) / 1 days;
        return (day < 7)? (day + 1) : 0;
    }

    function tokenXbg() external view returns (address) {
        return address(_tokenXbg);
    }

    function getPools() external view returns (address[4] memory) {
        return _pools;
    }

    function totalRewardForPool(address pool) external view returns (uint256, uint256[7] memory) {
        uint256 poolReward = 0;
        uint256[7] memory dailyRewards;
        for (uint256 i = 0; i < 7; ++i) {
            dailyRewards[i] = _dailyAccumulator[pool][i].xbgTotalReward;
            poolReward = poolReward.add(dailyRewards[i]);

        }
        return (poolReward, dailyRewards);
    }

    function totalLPForPool(address pool) external view returns (uint256, uint256[7] memory) {
        uint256 lpAmount = 0;
        uint256[7] memory dailyLP;
        for (uint256 i = 0; i < 7; ++i) {
            dailyLP[i] = _dailyAccumulator[pool][i].lpTotalAmount;
            lpAmount = lpAmount.add(dailyLP[i]);

        }
        return (lpAmount, dailyLP);
    }

    function getStake(address user) external view returns (uint256[4] memory) {
        uint256[4] memory lpTokens;
        for (uint256 i = 0; i < 4; ++i) {
            lpTokens[i] = 0;
            for (uint256 j = 0; j < 7; ++j) {
                lpTokens[i] = lpTokens[i].add(_stakes[user][_pools[i]][j]);
            }
        }
        return lpTokens;
    }

    function getStakeInfoPerDay(address user, address pool) external view returns (uint256[7] memory) {
        uint256[7] memory lpTokens;
        for (uint256 i = 0; i < 7; ++i) {
            lpTokens[i] = _stakes[user][pool][i];
        }
        return lpTokens;
    }

    function calculateReward(address user, uint256 timestamp) external view returns(uint256[4] memory, uint256) {
        uint256[4] memory usersLP;
        uint256 xbgReward;

        if (timestamp == 0) {
            timestamp = block.timestamp;
        }

        for (uint256 i = 0; i < 4; ++i) {
            address pool = _pools[i];
            uint256 accumulateTotalLP = 0;
            uint256 accumulateUserLP = 0;
            for (uint256 j = 0; j < 7 && timestamp > _startTime + (j + 1) * 86400; ++j) {
                Accumulator memory dailyAccumulator = _dailyAccumulator[pool][j];
                accumulateTotalLP = accumulateTotalLP.add(dailyAccumulator.lpTotalAmount);
                uint256 stake = _stakes[user][pool][j];
                if (stake > 0) {
                    accumulateUserLP = accumulateUserLP.add(stake);
                    usersLP[i] = usersLP[i].add(stake);
                }
                if (accumulateUserLP > 0) {
                    uint256 dailyReward = dailyAccumulator.xbgTotalReward.mul(accumulateUserLP).div(accumulateTotalLP);
                    xbgReward = xbgReward.add(dailyReward);
                }
            }
        }

        return (usersLP, xbgReward);
    }

    /**
     * @dev Add stake
     * @param user user address
     * @param pool pool address
     * @param amount number of LP tokens
     */
    function addStake(address user, address pool, uint256 amount) external {
        require(block.timestamp >= _startTime, "The time has not come yet");
        require(block.timestamp <= _startTime + 7 days, "stakings has finished");
        require(_allowListOfPools[pool], "Pool not found");

        // transfer LP tokens from sender to contract
        IERC20(pool).transferFrom(_msgSender(), address(this), amount);

        uint256 day = (block.timestamp - _startTime) / 1 days;

        // add amount to daily LP total value
        Accumulator storage dailyAccumulator = _dailyAccumulator[pool][day];
        dailyAccumulator.lpTotalAmount = dailyAccumulator.lpTotalAmount.add(amount);

        // add stake info
        _stakes[user][pool][day] = _stakes[user][pool][day].add(amount);

        emit StakerAdded(user, pool, day + 1, amount);
    }

    /**
     * @dev Pick up reward and LP tokens
     */
    function claimReward(address user) external {
        uint256 xbgReward = 0;
        uint256[4] memory usersLP;

        for (uint256 i = 0; i < 4; ++i) {
            address pool = _pools[i];
            uint256 accumulateTotalLP = 0;
            uint256 accumulateUserLP = 0;
            for (uint256 j = 0; j < 7 && block.timestamp > _startTime + (j + 1) * 86400; ++j) {
                Accumulator storage dailyAccumulator = _dailyAccumulator[pool][j];
                accumulateTotalLP = accumulateTotalLP.add(dailyAccumulator.lpTotalAmount);
                uint256 stake = _stakes[user][pool][j];
                if (stake > 0) {
                    _stakes[user][pool][j] = 0;
                    dailyAccumulator.lpTotalAmount = dailyAccumulator.lpTotalAmount.sub(stake);
                    accumulateUserLP = accumulateUserLP.add(stake);
                    usersLP[i] = usersLP[i].add(stake);
                }
                if (accumulateUserLP > 0) {
                    uint256 dailyReward = dailyAccumulator.xbgTotalReward.mul(accumulateUserLP).div(accumulateTotalLP);
                    dailyAccumulator.xbgTotalReward = dailyAccumulator.xbgTotalReward.sub(dailyReward);
                    xbgReward = xbgReward.add(dailyReward);
                }
            }
            if (usersLP[i] > 0) {
                IERC20(_pools[i]).transfer(user, usersLP[i]);
            }
        }

        require(xbgReward > 0, "Reward is empty");

        _tokenXbg.transfer(user, xbgReward);

        emit StakerHasClaimedReward(user, usersLP, xbgReward);
    }
}
