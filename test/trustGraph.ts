import { deployTrustGraph } from "../scripts/deployers";
import { TrustGraph } from "../typechain-types";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("TrustGraph", async () => {
  let trustGraph: TrustGraph;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;

  const signature = "0xc83f50b69b63294e02de09f5ec61cae75d92914a649283d04c85c8c0047aad1268a5c72ce810cf6e5cd23e65755b2746a620298641a64a4093638335e2abc57a1c";
  const score = {
    from: "0x4A0c754fEACB01ABb449eaB5574a0aEA6FC5C9B8",
    to: "0x709961837DA9e54476F2E5D1572Fc930EB35389F",
    topicId: BigNumber.from(0),
    score: 10,
    confidence: 5
  }

  before(async () => {
    [user1, user2, user3] = await ethers.getSigners();
    trustGraph = await deployTrustGraph(false);
  });

  it("should register new question", async () => {
    let title = "how old are you?";
    await trustGraph.createTopic(title);

    const len = await trustGraph.getTopicsLength();
    expect(len).eq(1);

    const _title = await trustGraph.topics(0);
    expect(_title).eq(title);
  });

  it("should rate a user", async () => {
    await trustGraph.connect(user1).scoreUser(user2.address, 0, 5, 10);

    let score = await trustGraph.scores(user1.address, user2.address, 0);

    expect(score.score).eq(5);
    expect(score.confidence).eq(10);
  });

  it("should override rates", async () => {
    await trustGraph.connect(user1).scoreUser(user2.address, 0, 8, 4);

    let score = await trustGraph.scores(user1.address, user2.address, 0);

    expect(score.score).eq(8);
    expect(score.confidence).eq(4);
  });

  it("should add another question", async () => {
    let title = "what's your height?";
    await trustGraph.createTopic(title);

    const len = await trustGraph.getTopicsLength();
    expect(len).eq(2);

    const _title = await trustGraph.topics(1);
    expect(_title).eq(title);
  });

  it("should rate user 3", async () => {
    await trustGraph.connect(user2).scoreUser(user3.address, 1, 8, 4);

    let score = await trustGraph.scores(user2.address, user3.address, 1);

    expect(score.score).eq(8);
    expect(score.confidence).eq(4);
  });

  it("should not be able to score with wrong signature", async () => {
    const tx = trustGraph.scoreUserWithSignature(score, signature.replace('a', 'b'));
    await expect(tx).to.be.revertedWithCustomError(
      trustGraph,
      "NotSigner"
    );
  })
  it("should score with valid signature", async () => {
    await trustGraph.scoreUserWithSignature(score, signature);
    let _score = await trustGraph.scores(score.from, score.to, score.topicId);

    expect(_score.score).eq(score.score);
    expect(_score.confidence).eq(score.confidence);
  })
});
