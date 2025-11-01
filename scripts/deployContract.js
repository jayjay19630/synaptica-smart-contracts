const { ethers } = require("hardhat");

module.exports = async () => {
  const wallet = (await ethers.getSigners())[0];
  console.log(`Deploying contracts with wallet: ${wallet.address}\n`);

  const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry", wallet);
  const identityRegistry = await IdentityRegistry.deploy();
  await identityRegistry.deployTransaction.wait();
  console.log(`IdentityRegistry deployed to: ${identityRegistry.address}\n`);

  const ReputationRegistry = await ethers.getContractFactory("ReputationRegistry", wallet);
  const reputationRegistry = await ReputationRegistry.deploy(identityRegistry.address);
  await reputationRegistry.deployTransaction.wait();
  console.log(`ReputationRegistry deployed to: ${reputationRegistry.address}\n`);

  const ValidationRegistry = await ethers.getContractFactory("ValidationRegistry", wallet);
  const validationRegistry = await ValidationRegistry.deploy(identityRegistry.address);
  await validationRegistry.deployTransaction.wait();
  console.log(`ValidationRegistry deployed to: ${validationRegistry.address}\n`);

  return {
    identityRegistry: identityRegistry.address,
    reputationRegistry: reputationRegistry.address,
    validationRegistry: validationRegistry.address
  };
}
