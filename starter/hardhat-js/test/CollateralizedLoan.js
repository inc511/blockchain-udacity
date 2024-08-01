const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CollateralizedLoan", function () {
  async function deployCollateralizedLoanFixture() {
    const [deployer, borrower, lender] = await ethers.getSigners();
    const CollateralizedLoan = await ethers.getContractFactory("CollateralizedLoan");
    const loanContract = await CollateralizedLoan.deploy();
    return { loanContract, deployer, borrower, lender };
  }

  describe("Loan Request", function () {
    it("Should let a borrower deposit collateral and request a loan", async function () {
      const { loanContract, borrower } = await loadFixture(deployCollateralizedLoanFixture);

      const collateralAmount = ethers.parseEther("1");
      const interestRate = 5; // 5%
      const duration = 3600; // 1 hour

      const tx = await loanContract.connect(borrower).depositCollateralAndRequestLoan(interestRate, duration, { value: collateralAmount });
      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt.blockNumber);

      await expect(tx)
        .to.emit(loanContract, "LoanRequested")
        .withArgs(0, borrower.address, collateralAmount, collateralAmount, interestRate, block.timestamp + duration);
    });
  });

  describe("Funding a Loan", function () {
    it("Allows a lender to fund a requested loan", async function () {
      const { loanContract, borrower, lender } = await loadFixture(deployCollateralizedLoanFixture);

      const collateralAmount = ethers.parseEther("1");
      const interestRate = 5; // 5%
      const duration = 3600; // 1 hour

      await loanContract.connect(borrower).depositCollateralAndRequestLoan(interestRate, duration, { value: collateralAmount });

      await expect(
        loanContract.connect(lender).fundLoan(0, { value: collateralAmount })
      ).to.emit(loanContract, "LoanFunded")
        .withArgs(0, lender.address);
    });
  });

  describe("Repaying a Loan", function () {
    it("Enables the borrower to repay the loan fully", async function () {
      const { loanContract, borrower, lender } = await loadFixture(deployCollateralizedLoanFixture);

      const collateralAmount = ethers.parseEther("1");
      const interestRate = BigInt(5); // 5%
      const duration = 3600; // 1 hour
      const loanAmount = collateralAmount;
      const repaymentAmount = loanAmount + loanAmount * interestRate / BigInt(100);

      await loanContract.connect(borrower).depositCollateralAndRequestLoan(interestRate, duration, { value: collateralAmount });
      await loanContract.connect(lender).fundLoan(0, { value: loanAmount });

      await expect(
        loanContract.connect(borrower).repayLoan(0, { value: repaymentAmount })
      ).to.emit(loanContract, "LoanRepaid")
        .withArgs(0);
    });
  });

  describe("Claiming Collateral", function () {
    it("Permits the lender to claim collateral if the loan isn't repaid on time", async function () {
      const { loanContract, borrower, lender } = await loadFixture(deployCollateralizedLoanFixture);

      const collateralAmount = ethers.parseEther("1");
      const interestRate = 5; // 5%
      const duration = 3600; // 1 hour
      const loanAmount = collateralAmount;

      await loanContract.connect(borrower).depositCollateralAndRequestLoan(interestRate, duration, { value: collateralAmount });
      await loanContract.connect(lender).fundLoan(0, { value: loanAmount });

      // Simulate the passage of time
      await ethers.provider.send("evm_increaseTime", [duration + 1]);
      await ethers.provider.send("evm_mine");

      await expect(
        loanContract.connect(lender).claimCollateral(0)
      ).to.emit(loanContract, "CollateralClaimed")
        .withArgs(0);
    });
  });
});
