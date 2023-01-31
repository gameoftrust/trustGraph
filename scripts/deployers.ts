import hre, { ethers } from "hardhat";
import { TrustGraph } from "../typechain-types";
export async function deployTrustGraph(
  verify: boolean = true
): Promise<TrustGraph> {
  const TrustGraph = await ethers.getContractFactory("TrustGraph");
  const trustGraph = await TrustGraph.deploy();

  await trustGraph.deployed();

  console.log("Trust Graph Deployed To: ", trustGraph.address);

  if (verify) {
    await hre.run("verify:verify", {
      address: trustGraph.address,
      constructorArguments: [],
    });
  }

  return trustGraph;
}
