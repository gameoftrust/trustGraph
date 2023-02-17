// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract TrustGraph {
    struct TrustTopic {
        string title;
    }

    struct Score {
        int8 score;
        uint8 confidance;
    }

    TrustTopic[] public topics;

    // from => (to => (topicId => score))
    mapping(address => mapping(address => mapping(uint256 => Score)))
        public scores;

    error TopicDoesNotExist();

    event TopicCreated(uint256 id, string title);
    event Scored(
        address from,
        address to,
        uint256 questionId,
        int8 score,
        uint8 confidance
    );

    function getTopicsLength() public view returns (uint256) {
        return topics.length;
    }

    function createTopic(string memory title) external {
        uint256 id = topics.length;
        topics.push(TrustTopic(title));
        emit TopicCreated(id, title);
    }

    function scoreUser(
        address to,
        uint256 topicId,
        int8 score,
        uint8 confiance
    ) external {
        if (topicId > topics.length) revert TopicDoesNotExist();

        scores[msg.sender][to][topicId] = Score(score, confiance);

        emit Scored(msg.sender, to, topicId, score, confiance);
    }
}
