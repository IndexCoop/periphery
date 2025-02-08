// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Owned} from "solmate/src/auth/Owned.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";

import {IReactorCallback} from "uniswapx/src/interfaces/IReactorCallback.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {ResolvedOrder, OutputToken, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";

import {IFlashMintDexV5} from "../interfaces/IFlashMintDexV5.sol";
import {ISetToken} from "../interfaces/ISetToken.sol";

/// @title FlashMintExecutor
/// @notice A UniswapX executor that routes fills to a FlashMint contract. The owner can
///         register enabled flash–mint tokens (typically SetTokens) and for each its corresponding
///         FlashMint contract. Then in the reactorCallback, if issuance is requested, the contract
///         checks that the set token is enabled and uses its flash–mint contract; similarly for redemption.
contract FlashMintExecutor is IReactorCallback, Owned {
    using SafeTransferLib for ERC20;

    /// @notice Constant used to represent native ETH.
    address constant ETH = address(0xEeeeeEeeeeeEeeeeeeeEEEeeeeEeeeeeeeEEeE);

    event FlashMintTokenAdded(address indexed token, address indexed flashMintContract);
    event FlashMintTokenRemoved(address indexed token);

    /// @notice Error when caller of reactorCallback is not the expected reactor.
    error MsgSenderNotReactor();
    /// @notice Error when a native ETH transfer fails.
    error NativeTransferFailed();

    IReactor public immutable reactor;
    WETH public immutable weth;

    // Mapping of enabled flash–mint tokens (typically SetTokens) to a boolean flag.
    mapping(address => bool) public flashMintEnabled;
    // Mapping from an enabled flash–mint token (SetToken) to its flash–mint contract.
    mapping(address => IFlashMintDexV5) public flashMintForToken;

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) {
            revert MsgSenderNotReactor();
        }
        _;
    }

    constructor(
        IReactor _reactor,
        address _weth,
        address _owner
    ) Owned(_owner) {
        require(_weth != address(0), "Invalid WETH address");
        reactor = _reactor;
        weth = WETH(payable(_weth));
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Owner Functions: Flash–Mint Token Management
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Enables a flash–mint token and registers its flash–mint contract.
    /// @param token The flash–mint token (e.g. a SetToken) to enable.
    /// @param flashMintContract The FlashMint contract to use for this token.
    function addFlashMintToken(address token, IFlashMintDexV5 flashMintContract) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(address(flashMintContract) != address(0), "Invalid flashMint contract");
        flashMintEnabled[token] = true;
        flashMintForToken[token] = flashMintContract;
        emit FlashMintTokenAdded(token, address(flashMintContract));
    }

    /// @notice Removes a flash–mint token from the enabled list.
    /// @param token The flash–mint token to remove.
    function removeFlashMintToken(address token) external onlyOwner {
        flashMintEnabled[token] = false;
        delete flashMintForToken[token];
        emit FlashMintTokenRemoved(token);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Executor Functions: Forwarding orders to the reactor
    // ─────────────────────────────────────────────────────────────────────────────

    /// @notice Forwards a single order to the reactor with callback.
    function execute(SignedOrder calldata order, bytes calldata callbackData) external {
        reactor.executeWithCallback(order, callbackData);
    }

    /// @notice Forwards a batch of orders to the reactor with callback.
    function executeBatch(SignedOrder[] calldata orders, bytes calldata callbackData) external {
        reactor.executeBatchWithCallback(orders, callbackData);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Reactor Callback Implementation
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @notice UniswapX reactor callback that fills orders via the appropriate FlashMint contract.
     *
     * The callbackData is ABI–decoded as follows:
     * - address[] tokensToApproveForFlashMint: tokens to approve for the flash–mint contract.
     * - address[] tokensToApproveForReactor: tokens to approve for the reactor.
     * - ISetToken setToken: the SetToken to be issued or redeemed.
     * - uint256 setAmount: the SetToken amount to issue/redeem.
     * - address inputOutputToken: the ERC20 token (or ETH) used as input for issuance, or desired output for redemption.
     * - uint256 inputOutputTokenAmount: the max input (for issuance) or min output (for redemption) amount.
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

        // Approve tokens to the FlashMint contract and the reactor.
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
            // For issuance, the flash–mint token to issue is setToken.
            require(flashMintEnabled[address(setToken)], "FlashMint not enabled for issuance");
            if (inputOutputToken == ETH) {
                flashMintContract.issueExactSetFromETH{value: inputOutputTokenAmount}(
                    setToken,
                    setAmount,
                    swapDataCollateral,
                    swapDataInputOutputToken
                );
            } else {
                flashMintContract.issueExactSetFromERC20(
                    setToken,
                    setAmount,
                    inputOutputToken,
                    inputOutputTokenAmount,
                    swapDataCollateral,
                    swapDataInputOutputToken
                );
            }
        } else {
            // For redemption, the flash–mint token being redeemed is setToken.
            require(flashMintEnabled[address(setToken)], "FlashMint not enabled for redemption");
            if (inputOutputToken == ETH) {
                flashMintContract.redeemExactSetForETH(
                    setToken,
                    setAmount,
                    inputOutputTokenAmount,
                    swapDataCollateral,
                    swapDataInputOutputToken
                );
            } else {
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

        // Refund any excess native ETH to the reactor.
        if (address(this).balance > 0) {
            transferNative(address(reactor), address(this).balance);
        }
    }

    /// @dev Returns the flash–mint contract associated with a given set token.
    function getFlashMintContract(ISetToken setToken) internal view returns (IFlashMintDexV5) {
        IFlashMintDexV5 flashMintContract = flashMintForToken[address(setToken)];
        require(address(flashMintContract) != address(0), "No flashMint contract for this token");
        return flashMintContract;
    }

    /**
     * @notice Transfers native ETH to the specified recipient.
     * @param recipient The address to receive the ETH.
     * @param amount The amount of ETH to transfer.
     */
    function transferNative(address recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert NativeTransferFailed();
    }

    /// @notice Receive function to allow contract to accept ETH.
    receive() external payable {}
}
