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

    /// @dev used for function argument
    struct Endorsement {
        uint256 nonce;
        address from;
        address to;
        RawScore[] scores;
    }

    /// @dev used only in Endorsement struct
    struct RawScore {
        uint256 topicId;
        int8 score;
        uint8 confidence;
    }

    struct Score {
        address from;
        address to;
        uint256 topicId;
        int8 score;
        uint8 confidence;
    }

    bytes32 public constant ENDORSEMENT_TYPE_HASH =
        keccak256(
            "Endorsement(uint256 nonce,address from,address to,RawScore[] scores)RawScore(uint256 topicId,int8 score,uint8 confidence)"
        );

    bytes32 public constant RAW_SCORE_TYPE_HASH =
        keccak256("RawScore(uint256 topicId,int8 score,uint8 confidence)");

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

    /// @notice Endorse another user on various topics, the "from" is ignored
    /// @param endorsement the endorsement submitted
    function endorseUser(Endorsement memory endorsement) external {
        endorsement.from = msg.sender;
        _endorseUser(endorsement);
    }

    /// @notice submit a score using an EIP712 signature from the sender of the score
    /// which is the "from" field of the "score" object passed to this function
    /// @param endorsement score object according to Score struct
    /// @param signature a signature on the score object from the sender
    function endorseUserWithSignature(
        Endorsement memory endorsement,
        bytes memory signature
    ) external {
        if (_getSigner(endorsement, signature) != endorsement.from)
            revert NotSigner();
        _endorseUser(endorsement);
    }

    // ================ INTERNAL FUNCTIONS ==============

    /// @notice saves the score object from endorsement
    /// @dev the event emitted is intended to be read off-chain to create a graph of scores
    /// @param endorsement score object
    function _endorseUser(Endorsement memory endorsement) internal {
        address _from = endorsement.from;
        address _to = endorsement.to;
        for (uint8 i = 0; i < endorsement.scores.length; i++) {
            RawScore memory rawScore = endorsement.scores[i];
            if (rawScore.topicId > topics.length) revert TopicDoesNotExist();
            scores.push(
                Score(
                    _from,
                    _to,
                    rawScore.topicId,
                    rawScore.score,
                    rawScore.confidence
                )
            );
            emit Scored(
                _from,
                _to,
                rawScore.topicId,
                rawScore.score,
                rawScore.confidence
            );
        }
    }

    /// @notice hashes RawScore object
    /// @param rawScore rawScore object
    /// @return hash struct hash of RawScore object
    function hash(RawScore memory rawScore) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    RAW_SCORE_TYPE_HASH,
                    rawScore.topicId,
                    rawScore.score,
                    rawScore.confidence
                )
            );
    }

    /// @notice hashes RawScores array objects
    /// @param rawScores rawScore object
    /// @return hash array struct hash of RawScore object
    function hash(RawScore[] memory rawScores) internal pure returns (bytes32) {
        bytes memory _hash;
        for (uint8 i = 0; i < rawScores.length; i++)
            _hash = abi.encodePacked(_hash, hash(rawScores[i]));
        return keccak256(_hash);
    }

    /// @notice hashes Endorsement array object
    /// @param endorsement endorsement object
    /// @return hash struct hash of Endorsement object
    function hash(
        Endorsement memory endorsement
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ENDORSEMENT_TYPE_HASH,
                    endorsement.nonce,
                    endorsement.from,
                    endorsement.to,
                    hash(endorsement.scores)
                )
            );
    }

    /// @notice calculates hash digest of Endorsement object for EIP-712 signature verification
    /// @param endorsement Endorsement object
    /// @return digest hash digest
    function digest(
        Endorsement memory endorsement
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    hash(endorsement)
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

    /// @notice recovers the signer of the Endorsement object from it's signature according to EIP-712 standard
    /// @param endorsement Endorsement object
    /// @param sig signature
    /// @return singer
    function _getSigner(
        Endorsement memory endorsement,
        bytes memory sig
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(sig);
        return ecrecover(digest(endorsement), v, r, s);
    }

    // ================ MODIFIERS ==============

    modifier onlyAuthor(uint256 topicId) {
        if (msg.sender != topics[topicId].author) revert OnlyAuthor();
        _;
    }
}
