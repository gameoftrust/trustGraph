// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract TrustGraph {
    struct TrustQuestion {
        string title;
    }

    TrustQuestion[] public questions;

    // from => (to => (questionId => score))
    mapping(address => mapping(address => mapping(uint256 => int8)))
        public scores;

    error QuestionDoesNotExist();

    event QuestionCreated(uint256 id, string title);
    event Rated(address from, address to, uint256 questionId, int8 score);

    function createQuestion(string memory title) external {
        uint256 id = questions.length;
        questions.push(TrustQuestion(title));
        emit QuestionCreated(id, title);
    }

    function scoreUser(address to, uint256 questionId, int8 score) external {
        if (questionId < questions.length) revert QuestionDoesNotExist();

        scores[msg.sender][to][questionId] = score;

        emit Rated(msg.sender, to, questionId, score);
    }
}
