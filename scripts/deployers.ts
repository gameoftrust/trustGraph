import hre, { ethers, upgrades } from "hardhat";
import { TrustGraph } from "../typechain-types";
export async function deployTrustGraph(
  verify: boolean = true
): Promise<TrustGraph> {
  const TrustGraphFactory = await ethers.getContractFactory("TrustGraph");
  const trustGraph = await upgrades.deployProxy(TrustGraphFactory, []);

  await trustGraph.deployed();

  const implementationAddress = await upgrades.erc1967.getImplementationAddress(trustGraph.address);

  console.log("Trust Graph Deployed To: ", trustGraph.address);
  console.log("Implementation Address", implementationAddress);

  if (verify) {
    await hre.run("verify:verify", {
      address: implementationAddress,
      constructorArguments: [],
    });
  }

  return trustGraph as TrustGraph;
}
