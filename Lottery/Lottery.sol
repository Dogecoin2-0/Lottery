// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AdvancedLottery is VRFConsumerBase, Ownable {
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public lotteryEndTime;
    address[] public participants;
    address public recentWinner;
    uint256 public randomness;
    bool public lotteryOpen = false;

    // Events
    event LotteryEntered(address participant);
    event RequestedRandomness(bytes32 requestId);
    event WinnerPicked(address winner);

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee
    )
        VRFConsumerBase(_vrfCoordinator, _linkToken)
    {
        keyHash = _keyHash;
        fee = _fee;
    }

    function startLottery(uint256 _duration) public onlyOwner {
        require(!lotteryOpen, "Lottery is already open");
        lotteryOpen = true;
        lotteryEndTime = block.timestamp + _duration;
        participants = new address ;
    }

    function enterLottery() public payable {
        require(lotteryOpen, "Lottery is not open");
        require(block.timestamp < lotteryEndTime, "Lottery has ended");
        require(msg.value == 0.1 ether, "Entry fee is 0.1 BNB");

        participants.push(msg.sender);
        emit LotteryEntered(msg.sender);
    }

    function endLottery() public onlyOwner {
        require(lotteryOpen, "Lottery is not open");
        require(block.timestamp >= lotteryEndTime, "Lottery is still ongoing");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");

        lotteryOpen = false;
        bytes32 requestId = requestRandomness(keyHash, fee);
        emit RequestedRandomness(requestId);
    }

    function fulfillRandomness(bytes32 /* requestId */, uint256 _randomness) internal override {
        require(!lotteryOpen, "Lottery is not ended");
        require(_randomness > 0, "Random-not-found");

        randomness = _randomness;
        uint256 winnerIndex = randomness % participants.length;
        recentWinner = participants[winnerIndex];
        payable(recentWinner).transfer(address(this).balance);
        emit WinnerPicked(recentWinner);
    }

    // Function to withdraw LINK (Chainlink token) from the contract, in case it's needed
    function withdrawLink() external onlyOwner {
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "Failed to transfer LINK");
    }
}
