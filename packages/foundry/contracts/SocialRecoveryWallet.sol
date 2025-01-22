//SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

contract SocialRecoveryWallet {
  address public owner;
  mapping(address => bool) public isGuardian;
  mapping(address => mapping(address => bool)) private guardianVotes;
  mapping(address => uint256) private votesReceived;
  address[] private guardians;
  uint256 private requiredVotes;

  event NewOwnerSignaled(address by, address proposedOwner);
  event RecoveryExecuted(address newOwner);

  error NotOwner();
  error NotGuardian();
  error AlreadyGuardian();
  error NotExistingGuardian();
  error AlreadyVoted();
  error CallFailed();

  constructor(
    address[] memory _guardians
  ) {
    owner = msg.sender;
    requiredVotes = _guardians.length;
    for (uint256 i = 0; i < _guardians.length; i++) {
      isGuardian[_guardians[i]] = true;
      guardians.push(_guardians[i]);
    }
  }

  modifier onlyOwner() {
    if (msg.sender != owner) {
      revert NotOwner();
    }
    _;
  }

  modifier onlyGuardian() {
    if (!isGuardian[msg.sender]) {
      revert NotGuardian();
    }
    _;
  }

  function call(
    address callee,
    uint256 value,
    bytes calldata data
  ) external payable onlyOwner returns (bytes memory) {
    (bool success, bytes memory result) = callee.call{ value: value }(data);
    if (!success) {
      revert CallFailed();
    }
    return result;
  }

  function signalNewOwner(
    address _proposedOwner
  ) external onlyGuardian {
    if (guardianVotes[msg.sender][_proposedOwner]) {
      revert AlreadyVoted();
    }

    guardianVotes[msg.sender][_proposedOwner] = true;
    votesReceived[_proposedOwner]++;

    emit NewOwnerSignaled(msg.sender, _proposedOwner);

    if (votesReceived[_proposedOwner] == requiredVotes) {
      owner = _proposedOwner;

      for (uint256 i = 0; i < guardians.length; i++) {
        guardianVotes[guardians[i]][_proposedOwner] = false;
      }
      votesReceived[_proposedOwner] = 0;

      emit RecoveryExecuted(_proposedOwner);
    }
  }

  function addGuardian(
    address _guardian
  ) external onlyOwner {
    if (isGuardian[_guardian]) {
      revert AlreadyGuardian();
    }
    isGuardian[_guardian] = true;
    guardians.push(_guardian);
    requiredVotes++;
  }

  function removeGuardian(
    address _guardian
  ) external onlyOwner {
    if (!isGuardian[_guardian]) {
      revert NotExistingGuardian();
    }
    isGuardian[_guardian] = false;

    for (uint256 i = 0; i < guardians.length; i++) {
      if (guardians[i] == _guardian) {
        guardians[i] = guardians[guardians.length - 1];
        guardians.pop();
        break;
      }
    }
    requiredVotes--;
  }

  receive() external payable { }
}
