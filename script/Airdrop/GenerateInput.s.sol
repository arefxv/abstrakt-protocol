// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";

// Merkle tree input file generator script
contract GenerateInput is Script {
    uint256 private constant AMOUNT = 100 * 1e18;
    string[] types = new string[](2);
    uint256 count;
    string[] whitelist = new string[](10);
    string private constant INPUT_PATH = "/script/Airdrop/target/input.json";

    function run() public {
        types[0] = "address";
        types[1] = "uint";
        whitelist[0] = "0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D";
        whitelist[1] = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
        whitelist[2] = "0x2ea3970Ed82D5b30be821FAAD4a731D35964F7dd";
        whitelist[3] = "0xf6dBa02C01AF48Cf926579F77C9f874Ca640D91D";
        whitelist[4] = "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720";
        whitelist[5] = "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f";
        whitelist[6] = "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955";
        whitelist[7] = "0x976EA74026E726554dB657fA54763abd0C3a0aa9";
        whitelist[8] = "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc";
        whitelist[9] = "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65";

        count = whitelist.length;
        string memory input = _createJSON();

        vm.writeFile(string.concat(vm.projectRoot(), INPUT_PATH), input);

        console.log("DONE: The output is found at %s", INPUT_PATH);
    }

    function _createJSON() internal view returns (string memory) {
        string memory countString = vm.toString(count);
        string memory amountString = vm.toString(AMOUNT);
        string memory json = string.concat('{ "types": ["address", "uint"], "count":', countString, ',"values": {');
        for (uint256 i = 0; i < whitelist.length; i++) {
            if (i == whitelist.length - 1) {
                json = string.concat(
                    json,
                    '"',
                    vm.toString(i),
                    '"',
                    ': { "0":',
                    '"',
                    whitelist[i],
                    '"',
                    ', "1":',
                    '"',
                    amountString,
                    '"',
                    " }"
                );
            } else {
                json = string.concat(
                    json,
                    '"',
                    vm.toString(i),
                    '"',
                    ': { "0":',
                    '"',
                    whitelist[i],
                    '"',
                    ', "1":',
                    '"',
                    amountString,
                    '"',
                    " },"
                );
            }
        }
        json = string.concat(json, "} }");

        return json;
    }
}
