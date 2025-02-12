// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Owned} from "solmate/src/auth/Owned.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";

import {IFlashMintDexV5} from "../interfaces/IFlashMintDexV5.sol";
import {ISetToken} from "../interfaces/ISetToken.sol";

/**
 * @title FlashMintExecutor
 * @notice A UniswapX executor that routes fills to a FlashMint contract using ERC20 tokens only.
 *
 * The owner can register enabled FlashMint tokens (typically SetTokens) and for each its
 * corresponding FlashMint contract. In the reactorCallback, if issuance (or redemption)
 * is requested, the contract verifies that the SetToken is enabled and then calls the appropriate
 * FlashMint function.
 *
 * The callbackData passed into reactorCallback must be ABI-encoded as:
 * 
 *   abi.encode(
 *       address[] tokensToApproveForFlashMint, // Tokens to approve for the FlashMint contract
 *       address[] tokensToApproveForReactor,    // Tokens to approve for the reactor
 *       ISetToken setToken,                     // The SetToken to issue or redeem
 *       uint256 setAmount,                      // The SetToken amount to issue/redeem
 *       address inputOutputToken,               // The ERC20 token used as input (issuance) or desired output (redemption)
 *       uint256 inputOutputTokenAmount,         // The max input (issuance) or min output (redemption) amount
 *       IFlashMintDexV5.SwapData swapDataCollateral,       // Swap data for collateral
 *       IFlashMintDexV5.SwapData swapDataInputOutputToken,   // Swap data for the input/output token
 *       bool isIssuance                         // True for issuance, false for redemption
 *   )
 */
contract FlashMintExecutor is IReactorCallback, Owned {
    using SafeTransferLib for ERC20;

    event FlashMintTokenAdded(address indexed token, address indexed flashMintContract);
    event FlashMintTokenRemoved(address indexed token);

    /// @notice Reverts if reactorCallback is called by an address other than the expected reactor.
    error MsgSenderNotReactor();

    IReactor public immutable reactor;

    // Mapping of enabled FlashMint tokens (typically SetTokens) to a boolean flag.
    mapping(address => bool) public flashMintEnabled;
    // Mapping from an enabled FlashMint token (SetToken) to its FlashMint contract.
    mapping(address => IFlashMintDexV5) public flashMintForToken;

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) {
            revert MsgSenderNotReactor();
        }
        _;
    }

    constructor(
        IReactor _reactor,
        address _owner
    ) Owned(_owner) {
        reactor = _reactor;
    }

    /// @notice Enables a token and registers its FlashMint contract.
    /// @param token The token (e.g. a SetToken) to enable.
    /// @param flashMintContract The FlashMint contract to use for this token.
    function addFlashMintToken(address token, IFlashMintDexV5 flashMintContract) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(address(flashMintContract) != address(0), "Invalid FlashMint contract");
        flashMintEnabled[token] = true;
        flashMintForToken[token] = flashMintContract;
        emit FlashMintTokenAdded(token, address(flashMintContract));
    }

    /// @notice Removes a token from the enabled list.
    /// @param token The token to remove.
    function removeFlashMintToken(address token) external onlyOwner {
        flashMintEnabled[token] = false;
        delete flashMintForToken[token];
        emit FlashMintTokenRemoved(token);
    }

    /// @notice Withdraws a token from the contract.
    /// @param _token The token to withdraw.
    /// @param _amount The amount to withdraw.
    function withdrawToken(IERC20 _token, uint256 _amount) external onlyOwner {
        _token.transfer(msg.sender, _amount);
    }

    /// @notice Forwards a single order to the reactor with callback.
    function execute(SignedOrder calldata order, bytes calldata callbackData) external {
        reactor.executeWithCallback(order, callbackData);
    }

    /// @notice Forwards a batch of orders to the reactor with callback.
    function executeBatch(SignedOrder[] calldata orders, bytes calldata callbackData) external {
        reactor.executeBatchWithCallback(orders, callbackData);
    }

    /**
     * @notice UniswapX reactor callback that fills orders via the appropriate FlashMint contract.
     *
     * The callbackData is ABI-decoded as follows:
     * - address[] tokensToApproveForFlashMint: tokens to approve for the FlashMint contract.
     * - address[] tokensToApproveForReactor: tokens to approve for the reactor.
     * - ISetToken setToken: the SetToken to issue or redeem.
     * - uint256 setAmount: the SetToken amount to issue/redeem.
     * - address inputOutputToken: the ERC20 token used as input (issuance) or desired output (redemption).
     * - uint256 inputOutputTokenAmount: the max input (issuance) or min output (redemption) amount.
     * - IFlashMintDexV5.SwapData swapDataCollateral: swap data for collateral.
     * - IFlashMintDexV5.SwapData swapDataInputOutputToken: swap data for the input/output token.
     * - bool isIssuance: true for issuance, false for redemption.
     */
    function reactorCallback(
        ResolvedOrder[] calldata, 
        bytes calldata callbackData
    ) external override onlyReactor {
        (
            address[] memory tokensToApproveForFlashMint,
            address[] memory tokensToApproveForReactor,
            ISetToken setToken,
            uint256 setAmount,
            address inputOutputToken,
            uint256 inputOutputTokenAmount,
            IFlashMintDexV5.SwapData memory swapDataCollateral,
            IFlashMintDexV5.SwapData memory swapDataInputOutputToken,
            bool isIssuance
        ) = abi.decode(
            callbackData,
            (
                address[],
                address[],
                ISetToken,
                uint256,
                address,
                uint256,
                IFlashMintDexV5.SwapData,
                IFlashMintDexV5.SwapData,
                bool
            )
        );

        IFlashMintDexV5 flashMintContract = getFlashMintContract(setToken);
        unchecked {
            for (uint256 i = 0; i < tokensToApproveForFlashMint.length; i++) {
                ERC20(tokensToApproveForFlashMint[i]).safeApprove(address(flashMintContract), type(uint256).max);
            }
            for (uint256 i = 0; i < tokensToApproveForReactor.length; i++) {
                ERC20(tokensToApproveForReactor[i]).safeApprove(address(reactor), type(uint256).max);
            }
        }

        if (isIssuance) {
            require(flashMintEnabled[address(setToken)], "FlashMint not enabled for issuance");
            flashMintContract.issueExactSetFromERC20(
                setToken,
                setAmount,
                inputOutputToken,
                inputOutputTokenAmount,
                swapDataCollateral,
                swapDataInputOutputToken
            );
        } else {
            require(flashMintEnabled[address(setToken)], "FlashMint not enabled for redemption");
            flashMintContract.redeemExactSetForERC20(
                setToken,
                setAmount,
                inputOutputToken,
                inputOutputTokenAmount,
                swapDataCollateral,
                swapDataInputOutputToken
            );
        }
    }

    function getFlashMintContract(ISetToken setToken) internal view returns (IFlashMintDexV5) {
        IFlashMintDexV5 flashMintContract = flashMintForToken[address(setToken)];
        require(address(flashMintContract) != address(0), "No flashMint contract for this token");
        return flashMintContract;
    }
}
