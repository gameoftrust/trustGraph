// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract TrustGraph {
    // ================ STATE VARIABLES ==============
    struct TrustTopic {
        uint256 id; // position of this topic in topics array
        string title;
        string description;
        address author;
    }

    struct Score {
        address from;
        address to;
        uint256 topicId;
        int8 score;
        uint8 confidence;
    }

    bytes32 public constant SCORE_TYPE_HASH =
        keccak256(
            "Score(address from,address to,uint256 topicId,int8 score,uint8 confidence)"
        );

    bytes32 public constant DOMAIN_SEPARATOR =
        keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name)"),
                keccak256(bytes("Game of Trust"))
            )
        );

    TrustTopic[] public topics;

    // from => (to => (topicId => score))
    Score[] public scores;

    // ================ ERRORS ==============
    error TopicDoesNotExist();
    error NotSigner();
    error OnlyAuthor();

    // ================ EVENTS ==============
    event TopicCreated(
        uint256 id,
        string title,
        string description,
        address author
    );
    event Scored(
        address from,
        address to,
        uint256 questionId,
        int8 score,
        uint8 confidence
    );

    // ================ PUBLIC VIEWS ==============

    /// @notice returns the length of the topics array
    /// @return length
    function getTopicsLength() public view returns (uint256) {
        return topics.length;
    }

    /// @notice returns the length of scores array
    /// @return length
    function getScoresLength() public view returns (uint256) {
        return scores.length;
    }

    /// @notice gets a slice of the scores array
    /// @param fromIndex start index of slice (inclusive)
    /// @param toIndex end index of slice (inclusive)
    /// @return scores the sliced list
    function getScores(
        uint256 fromIndex,
        uint256 toIndex
    ) public view returns (Score[] memory) {
        Score[] memory _scores = new Score[](toIndex - fromIndex + 1);
        for (uint256 i = fromIndex; i <= toIndex; i++) {
            _scores[i] = scores[i];
        }
        return _scores;
    }

    // ================ OPEN EXTERNAL FUNCTIONS ==============

    /// @notice creates a new topic, the id of the newly created topic will it's index
    /// in the topics array
    /// @param title : the title of the topic
    function createTopic(
        string memory title,
        string memory description
    ) external {
        uint256 id = topics.length;
        topics.push(TrustTopic(id, title, description, msg.sender));
        emit TopicCreated(id, title, description, msg.sender);
    }

    /// @notice author of the topics can change it's description
    /// @param topicId index of the topic in topics array
    /// @param description the new description
    function editTopic(
        uint256 topicId,
        string memory description
    ) external onlyAuthor(topicId) {
        topics[topicId].description = description;
    }

    /// @notice score user, from msg.sender to "to"
    /// @param to recipient of the score
    /// @param topicId index of the topic in the topics array
    /// @param score score that he msg.sender is giving
    /// @param confidence the level of confidence of the msg.sender in the score
    function scoreUser(
        address to,
        uint256 topicId,
        int8 score,
        uint8 confidence
    ) external {
        _scoreUser(Score(msg.sender, to, topicId, score, confidence));
    }

    /// @notice submit a score using an EIP712 signature from the sender of the score
    /// which is the "from" field of the "score" object passed to this function
    /// @param score score object according to Score struct
    /// @param signature a signature on the score object from the sender
    function scoreUserWithSignature(
        Score memory score,
        bytes memory signature
    ) external {
        if (_getSigner(score, signature) != score.from) revert NotSigner();
        _scoreUser(score);
    }

    // ================ INTERNAL FUNCTIONS ==============

    /// @notice saves the score object
    /// @dev the event emitted is intended to be read off-chain to create a graph of scores
    /// @param score score object
    function _scoreUser(Score memory score) internal {
        if (score.topicId > topics.length) revert TopicDoesNotExist();
        scores.push(score);
        emit Scored(
            score.from,
            score.to,
            score.topicId,
            score.score,
            score.confidence
        );
    }

    /// @notice generates a has struct of score object as specified in the EIP712 standard
    /// @param score score object
    /// @return hash the hash struct
    function _getHashStruct(
        Score memory score
    ) internal pure returns (bytes32 hash) {
        return
            keccak256(
                abi.encode(
                    SCORE_TYPE_HASH,
                    score.from,
                    score.to,
                    score.topicId,
                    score.score,
                    score.confidence
                )
            );
    }

    /// @notice generates a hash that is signed according to EIP712 standard
    /// @param score score object
    /// @return hash
    function _getEncodedHash(
        Score memory score
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    _getHashStruct(score)
                )
            );
    }

    /// @notice given a hex signature it extracts its r, s and v components
    /// @param sig bytes of the signature
    /// @return r
    /// @return s
    /// @return v
    function _splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    /// @notice recovers the signer of the score object from it's signature according to EIP712 standard
    /// @param score score object
    /// @param sig signature
    /// @return singer
    function _getSigner(
        Score memory score,
        bytes memory sig
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(sig);
        return ecrecover(_getEncodedHash(score), v, r, s);
    }

    // ================ MODIFIERS ==============

    modifier onlyAuthor(uint256 topicId) {
        if (msg.sender != topics[topicId].author) revert OnlyAuthor();
        _;
    }
}
