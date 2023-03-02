import { deployTrustGraph } from "../scripts/deployers";
import { TrustGraph, TrustGraph__factory } from "../typechain-types";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("TrustGraph", async () => {
  let trustGraph: TrustGraph;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;

  const signature = "0xe988c5f7294694a9fb693686e99c23c000a9fa83cdd5b6e9668d96655e232bc611d4a1425a681574e1633144366cc8b80a5972e9673e598b25423de8ccf2f6e01c";
  const signedEndorsement = {
    nonce: 0,
    from: "0x7f96cE96b4E7e1F8AcCDFFFF1919513599a15B6E",
    to: "0x709961837DA9e54476F2E5D1572Fc930EB35389F",
    scores: [{
      topicId: BigNumber.from(1),
      score: 10,
      confidence: 5
    }, {
      topicId: BigNumber.from(2),
      score: 6,
      confidence: 2
    }
    ]
  }

  before(async () => {
    [user1, user2, user3] = await ethers.getSigners();
    trustGraph = await deployTrustGraph(false);
  });

  it("should register new question", async () => {
    const title = "how old are you?";
    const desc = "your age";
    await trustGraph.connect(user1).createTopic(title, desc);

    const len = await trustGraph.getTopicsLength();
    expect(len).eq(1);

    const _topic = await trustGraph.topics(0);
    expect(_topic.title).eq(title);
    expect(_topic.description).eq(desc);
    expect(_topic.author).eq(user1.address);
  });

  it("should rate a user", async () => {
    const endorsement = {
      nonce: 0,
      from: user1.address,
      to: user2.address,
      scores: [
        {
          topicId: 0,
          score: 5,
          confidence: 10
        }
      ]
    }
    await trustGraph.connect(user1).endorseUser(endorsement);

    const score = await trustGraph.scores(0);
    const len = await trustGraph.getTopicsLength();

    expect(score.from).eq(user1.address);
    expect(score.to).eq(user2.address);
    expect(score.score).eq(5);
    expect(score.confidence).eq(10);
    expect(len).eq(1);
  });

  it("should add another question", async () => {
    const title = "what's your height?";
    const desc = "your height"
    await trustGraph.connect(user2).createTopic(title, desc);

    const len = await trustGraph.getTopicsLength();
    expect(len).eq(2);

    const _topic = await trustGraph.topics(1);
    expect(_topic.title).eq(title);
    expect(_topic.description).eq(desc);
    expect(_topic.author).eq(user2.address);
  });

  it("should add another question (id 2 )", async () => {
    const title = "did you go to college?";
    const desc = "degree"
    await trustGraph.connect(user2).createTopic(title, desc);

    const len = await trustGraph.getTopicsLength();
    expect(len).eq(3);

    const _topic = await trustGraph.topics(2);
    expect(_topic.title).eq(title);
    expect(_topic.description).eq(desc);
    expect(_topic.author).eq(user2.address);
  });

  it("user 1 should fail to edit user2's topic", async () => {
    const tx = trustGraph.connect(user2).editTopic(0, "new desc");
    await expect(tx).to.be.revertedWithCustomError(
      trustGraph,
      "OnlyAuthor"
    );
  })

  it("user 1 should be able to edit topic 0", async () => {
    await trustGraph.connect(user1).editTopic(0, "new desc");
    expect((await trustGraph.topics(0)).description).eq("new desc");
  })

  it("should rate user 3", async () => {
    const endorsement = {
      nonce: 0,
      from: user2.address,
      to: user3.address,
      scores: [
        {
          topicId: 1,
          score: 8,
          confidence: 4
        }
      ]
    }
    await trustGraph.connect(user2).endorseUser(endorsement);

    let score = await trustGraph.scores(1);

    expect(score.from).eq(user2.address);
    expect(score.to).eq(user3.address);
    expect(score.topicId).eq(1);
    expect(score.score).eq(8);
    expect(score.confidence).eq(4);
  });

  it("should rate user 3 with different from passed in", async () => {
    const endorsement = {
      nonce: 0,
      from: user3.address,
      to: user3.address,
      scores: [
        {
          topicId: 1,
          score: 8,
          confidence: 4
        }
      ]
    }
    await trustGraph.connect(user2).endorseUser(endorsement);

    let score = await trustGraph.scores(1);

    expect(score.from).eq(user2.address);
    expect(score.to).eq(user3.address);
    expect(score.topicId).eq(1);
    expect(score.score).eq(8);
    expect(score.confidence).eq(4);
  });

  it("should not be able to score with wrong signature", async () => {
    const tx = trustGraph.endorseUserWithSignature(signedEndorsement, signature.replace('a', 'b'));
    await expect(tx).to.be.revertedWithCustomError(
      trustGraph,
      "NotSigner"
    );
  })
  it("should score with valid signature", async () => {
    await trustGraph.endorseUserWithSignature(signedEndorsement, signature);
    let _score3 = await trustGraph.scores(3);
    let _score4 = await trustGraph.scores(4);

    // both scores should have same from, to
    expect(_score3.from).eq(_score4.from);
    expect(_score3.to).eq(_score4.to);
    expect(_score3.from).eq(signedEndorsement.from);
    expect(_score3.to).eq(signedEndorsement.to);

    // score 3 check
    expect(_score3.topicId).eq(signedEndorsement.scores[0].topicId);
    expect(_score3.score).eq(signedEndorsement.scores[0].score);
    expect(_score3.confidence).eq(signedEndorsement.scores[0].confidence);

    // score 4 check
    expect(_score4.topicId).eq(signedEndorsement.scores[1].topicId);
    expect(_score4.score).eq(signedEndorsement.scores[1].score);
    expect(_score4.confidence).eq(signedEndorsement.scores[1].confidence);

  })
});
