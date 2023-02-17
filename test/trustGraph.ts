import { deployTrustGraph } from "../scripts/deployers";
import { TrustGraph } from "../typechain-types";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("TrustGraph", async () => {
  let trustGraph: TrustGraph;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;

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
    expect(score.confidance).eq(10);
  });

  it("should override rates", async () => {
    await trustGraph.connect(user1).scoreUser(user2.address, 0, 8, 4);

    let score = await trustGraph.scores(user1.address, user2.address, 0);

    expect(score.score).eq(8);
    expect(score.confidance).eq(4);
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
    expect(score.confidance).eq(4);
  });
});
