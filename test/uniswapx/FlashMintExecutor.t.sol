// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../../src/uniswapx/FlashMintExecutor.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import "../../src/interfaces/IFlashMintDexV5.sol";

contract FlashMintExecutorTest is Test {
    FlashMintExecutor flashMintExecutor;

    address public owner;
    address public mockReactor;
    address public mockSetToken;
    address public mockFlashMint;
    address public nonOwner;

    event FlashMintTokenAdded(address indexed token, address indexed flashMintContract);
    event FlashMintTokenRemoved(address indexed token);

    function setUp() public {
        owner = msg.sender;

        mockReactor = address(0x1);
        mockSetToken = address(0x2);
        mockFlashMint = address(0x3);
        nonOwner = address(0x4);

        flashMintExecutor = new FlashMintExecutor(
            IReactor(mockReactor),
            owner
        );
    }

    function testConstructor() public {
        assertEq(address(flashMintExecutor.reactor()), mockReactor, "Incorrect reactor address");
        assertEq(flashMintExecutor.owner(), owner, "Incorrect owner address");
    }

    function testAddFlashMintToken() public {
        vm.expectEmit(true, false, false, true);
        emit FlashMintTokenAdded(mockSetToken, mockFlashMint);

        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(mockSetToken, IFlashMintDexV5(mockFlashMint));
        
        assertTrue(flashMintExecutor.flashMintEnabled(mockSetToken), "Token should be enabled");
        assertEq(
            address(flashMintExecutor.flashMintForToken(mockSetToken)), 
            mockFlashMint, 
            "Incorrect flash mint contract"
        );
    }

    function testCannotAddFlashMintTokenWithZeroAddresses() public {
        vm.expectRevert("Invalid token");
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(0), IFlashMintDexV5(mockFlashMint));

        vm.expectRevert("Invalid FlashMint contract");
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(mockSetToken, IFlashMintDexV5(address(0)));
    }

    function testCannotAddFlashMintTokenIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        flashMintExecutor.addFlashMintToken(mockSetToken, IFlashMintDexV5(mockFlashMint));
    }

    function testRemoveFlashMintToken() public {
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(mockSetToken, IFlashMintDexV5(mockFlashMint));
        
        vm.expectEmit(true, false, false, true);
        emit FlashMintTokenRemoved(mockSetToken);
        
        vm.prank(owner);
        flashMintExecutor.removeFlashMintToken(mockSetToken);
        
        assertFalse(flashMintExecutor.flashMintEnabled(mockSetToken), "Token should be disabled");
        assertEq(
            address(flashMintExecutor.flashMintForToken(mockSetToken)), 
            address(0), 
            "Flash mint contract should be removed"
        );
    }

    function testCannotRemoveFlashMintTokenIfNotOwner() public {
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(mockSetToken, IFlashMintDexV5(mockFlashMint));
        
        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        flashMintExecutor.removeFlashMintToken(mockSetToken);
    }

    function testUpdateFlashMintToken() public {
        address newMockFlashMint = address(0x99);
        
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(mockSetToken, IFlashMintDexV5(mockFlashMint));
        
        vm.expectEmit(true, true, false, false);
        emit FlashMintTokenAdded(mockSetToken, newMockFlashMint);
        
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(mockSetToken, IFlashMintDexV5(newMockFlashMint));
        
        assertTrue(flashMintExecutor.flashMintEnabled(mockSetToken), "Token should still be enabled");
        assertEq(
            address(flashMintExecutor.flashMintForToken(mockSetToken)), 
            newMockFlashMint, 
            "Flash mint contract should be updated"
        );
    }
}
