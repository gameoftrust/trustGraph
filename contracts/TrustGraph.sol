// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract TrustGraph {
    struct TrustTopic {
        string title;
    }

    struct Score {
        address from;
        address to;
        uint256 topicId;
        int8 score;
        uint8 confidence;
    }

    TrustTopic[] public topics;

    // from => (to => (topicId => score))
    mapping(address => mapping(address => mapping(uint256 => Score)))
        public scores;

    error TopicDoesNotExist();
    error NotSigner();

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
        uint8 confidence
    ) external {
        _scoreUser(Score(msg.sender, to, topicId, score, confidence));
    }

    function scoreUserWithSignature(
        Score memory score,
        bytes memory signature
    ) external {
        if (getSigner(score, signature) != score.from) revert NotSigner();
        _scoreUser(score);
    }

    function _scoreUser(Score memory score) internal {
        if (score.topicId > topics.length) revert TopicDoesNotExist();
        scores[score.from][score.to][score.topicId] = score;
        emit Scored(
            score.from,
            score.to,
            score.topicId,
            score.score,
            score.confidence
        );
    }

    function getHashStruct(
        Score memory score
    ) internal pure returns (bytes32 hash) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "Score(address from,address to,uint256 topicId,int8 score,uint8 confidence)"
                    ),
                    score.from,
                    score.to,
                    score.topicId,
                    score.score,
                    score.confidence
                )
            );
    }

    function getDomainSeparator()
        internal
        pure
        returns (bytes32 domainSeparator)
    {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name)"),
                    keccak256(bytes("Game of Trust"))
                )
            );
    }

    function getEncodedHash(
        Score memory score
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    getDomainSeparator(),
                    getHashStruct(score)
                )
            );
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function getSigner(
        Score memory score,
        bytes memory sig
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(sig);
        return ecrecover(getEncodedHash(score), v, r, s);
    }
}
