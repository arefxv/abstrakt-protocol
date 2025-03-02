// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {TokenPool} from "@chainlink-local/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from
    "@chainlink-local/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Pool} from "@chainlink-local/ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {IAbstraktGovernToken} from "../Interface/IAbstraktGovernToken.sol";

/**
 * @title AbstraktTokenPool
 * @author ArefXV https://github.com/arefxv
 * @dev Token pool for cross-chain token transfers with interest rate preservation
 * @notice Features include:
 * - CCIP-compatible token pool
 * - Interest rate preservation during cross-chain transfers
 * - Secure lock/burn and release/mint mechanisms
 */
contract AbstraktTokenPool is TokenPool {
    /*/////////////////////////////////////////////////////////////
                            FUNCTIONS
    /////////////////////////////////////////////////////////////*/
    constructor(IERC20 tokenAddress, address[] memory allowlist, address rmnProxy, address router)
        TokenPool(tokenAddress, 18, allowlist, rmnProxy, router)
    {}

    /*/////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/
    /**
     * @notice Locks or burns tokens for cross-chain transfer
     * @param lockOrBurnIn Lock/burn parameters
     * @return lockOrBurnOut Lock/burn output
     */
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);

        uint256 userinterestRate =
            IAbstraktGovernToken(address(i_token)).getAccountInterestRate(lockOrBurnIn.originalSender);

        IAbstraktGovernToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userinterestRate)
        });
    }

    /**
     * @notice Releases or mints tokens after cross-chain transfer
     * @param releaseOrMintIn Release/mint parameters
     * @return releaseOrMintOut Release/mint output
     */
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        returns (Pool.ReleaseOrMintOutV1 memory releaseOrMintOut)
    {
        _validateReleaseOrMint(releaseOrMintIn);

        address receiver = releaseOrMintIn.receiver;
        (uint256 userInterestRate) = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IAbstraktGovernToken(address(i_token)).mint(receiver, releaseOrMintIn.amount, userInterestRate);

        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}
