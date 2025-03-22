// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Oracle, IOracle} from "../src/Oracle.sol";
import {ExampleConsumer} from "../src/examples/ExampleConsumer.sol";

contract OracleTest is Test {
    Oracle public oracle;
    ExampleConsumer public consumer;

    address deployer;
    address thridPartyDeveloper;
    address user;
    address tee;

    uint256 public constant REQUEST_FEE = 0.001 ether;

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");
        thridPartyDeveloper = makeAddr("thridPartyDeveloper");
        tee = makeAddr("tee");

        deal(user, 100 ether);

        // Setup oracle
        vm.startPrank(deployer);
        oracle = new Oracle(REQUEST_FEE);
        oracle.grantRoles(tee, oracle.ROLE_TEE());
        vm.stopPrank();

        // Deploy consumer
        vm.prank(thridPartyDeveloper);
        consumer = new ExampleConsumer(address(oracle));
    }

    function test_requestTODOData() public {
        vm.prank(user);
        vm.expectEmit(false, false, false, false, address(oracle));
        emit IOracle.RestApiRequest(
            "",
            user,
            IOracle.Request({
                url: "https://jsonplaceholder.typicode.com/todos",
                urlEncrypted: false,
                method: IOracle.HttpMethod.GET,
                body: "",
                bodyEncrypted: false,
                headers: new IOracle.KeyValue[](0),
                queryParams: new IOracle.KeyValue[](0),
                responseFields: new IOracle.ResponseField[](0)
            })
        );
        consumer.requestTODOData{value: REQUEST_FEE}("1");
    }

    function test_fulfillTODOData() public {
        console.log("Oracle address: %s", address(oracle));
        console.log("Consumer address: %s", address(consumer));
        console.log("User address: %s", user);

        vm.prank(user);
        vm.expectEmit(false, false, false, false, address(oracle)); // don't check data for now
        emit IOracle.RestApiRequest(
            "",
            user,
            IOracle.Request({
                url: "",
                urlEncrypted: false,
                method: IOracle.HttpMethod.GET,
                body: "",
                bodyEncrypted: false,
                headers: new IOracle.KeyValue[](0),
                queryParams: new IOracle.KeyValue[](0),
                responseFields: new IOracle.ResponseField[](0)
            })
        );
        bytes32 requestId = consumer.requestTODOData{value: REQUEST_FEE}("1");

        bytes memory responseData = abi.encode(1, 1, false, "test");
        vm.prank(tee);
        oracle.fulfillRestApiRequest(requestId, responseData);

        ExampleConsumer.TODOData memory todoData = consumer.getLastTODOData();
        assertEq(todoData.id, 1);
        assertEq(todoData.userId, 1);
        assertEq(todoData.title, "test");
        assertEq(todoData.completed, false);
    }
}
