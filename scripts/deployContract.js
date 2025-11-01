const { ethers } = require("hardhat");

module.exports = async () => {
  const wallet = (await ethers.getSigners())[0];
  console.log(`Deploying contracts with wallet: ${wallet.address}\n`);

  // Step 1: Deploy IdentityRegistry with zero addresses (will be updated later)
  console.log("Step 1: Deploying IdentityRegistry...");
  const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry", wallet);
  const identityRegistry = await IdentityRegistry.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero);
  await identityRegistry.deployTransaction.wait();
  console.log(`IdentityRegistry deployed to: ${identityRegistry.address}\n`);

  // Step 2: Deploy ReputationRegistry with IdentityRegistry address
  console.log("Step 2: Deploying ReputationRegistry...");
  const ReputationRegistry = await ethers.getContractFactory("ReputationRegistry", wallet);
  const reputationRegistry = await ReputationRegistry.deploy(identityRegistry.address);
  await reputationRegistry.deployTransaction.wait();
  console.log(`ReputationRegistry deployed to: ${reputationRegistry.address}\n`);

  // Step 3: Deploy ValidationRegistry with IdentityRegistry address
  console.log("Step 3: Deploying ValidationRegistry...");
  const ValidationRegistry = await ethers.getContractFactory("ValidationRegistry", wallet);
  const validationRegistry = await ValidationRegistry.deploy(identityRegistry.address);
  await validationRegistry.deployTransaction.wait();
  console.log(`ValidationRegistry deployed to: ${validationRegistry.address}\n`);

  // Step 4: Update IdentityRegistry with ReputationRegistry and ValidationRegistry addresses
  console.log("Step 4: Linking registries to IdentityRegistry...");
  const tx1 = await identityRegistry.setReputationRegistry(reputationRegistry.address);
  await tx1.wait();
  console.log("ReputationRegistry linked to IdentityRegistry");

  const tx2 = await identityRegistry.setValidationRegistry(validationRegistry.address);
  await tx2.wait();
  console.log("ValidationRegistry linked to IdentityRegistry\n");

  console.log("=== Deployment Complete ===");
  console.log(`IdentityRegistry: ${identityRegistry.address}`);
  console.log(`ReputationRegistry: ${reputationRegistry.address}`);
  console.log(`ValidationRegistry: ${validationRegistry.address}\n`);

  return {
    identityRegistry: identityRegistry.address,
    reputationRegistry: reputationRegistry.address,
    validationRegistry: validationRegistry.address
  };
}
