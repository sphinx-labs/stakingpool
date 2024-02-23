// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MocaNftToken} from "../src/MocaNftToken.sol";
import {Script, console2} from "forge-std/Script.sol";
import {Sphinx, Network} from "@sphinx-labs/contracts/SphinxPlugin.sol";

contract CounterScript is Script, Sphinx {
    function setUp() public {
        sphinxConfig.owners = [address(0)]; // Add owner(s)
        sphinxConfig.orgId = ""; // Add Sphinx org ID
        sphinxConfig.testnets = [
            Network.sepolia,
            Network.polygon_mumbai
        ];
        sphinxConfig.projectName = "Moca";
        sphinxConfig.threshold = 1;
    }

    function run() public sphinx {
        new MocaNftToken("Moca NFT", "MOCA");
    }
}
