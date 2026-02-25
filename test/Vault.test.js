const { expect } = require("chai");
const { ethers } = require("hardhat");

const MockV3Aggregator = require("@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol");

describe("PegVault", function () {
    let vault;
    let owner;
    let user;
    let liquidator;
    let stablecoin;
    let mockfeed;

    const INITIAL_PRICE = 2000n * 10n ** 8n; // 8 decimals

    beforeEach(async function () {
        [owner, user, liquidator] = await ethers.getSigners();
        // Deploy mock price feed
        const MockFeed = await ethers.getContractFactory("MockV3Aggregator");
        mockFeed = await MockFeed.deploy(8, INITIAL_PRICE);

        const Vault = await ethers.getContractFactory("Vault");
        vault = await Vault.deploy(mockFeed.target, owner.address);

        const stablecoinAddress = await vault.stablecoin();
        stablecoin = await ethers.getContractAt("Stablecoin", stablecoinAddress);
    });

    it("should allow deposit", async function () {
        await vault.connect(user).deposit({ value: ethers.parseEther("1") });

        const collateral = await vault.collateralETH(user.address);
        expect(collateral).to.equal(ethers.parseEther("1"));
    });

    it("should mint if healthy", async function () {

        await vault.connect(user).deposit({ value: ethers.parseEther("1") });

        await vault.connect(user).mint(
            ethers.parseEther("1000")
        );

        const debt = await vault.debt(user.address);
        expect(debt).to.equal(ethers.parseEther("1000"));
    });

    it("should prevent unsafe withdraw", async function () {

        await vault.connect(user).deposit({ value: ethers.parseEther("1") });

        await vault.connect(user).mint(
            ethers.parseEther("1000")
        );

        await expect(
            vault.connect(user).withdraw(
                ethers.parseEther("0.9")
            )
        ).to.be.reverted;
    });

    it("should allow liquidation when unhealthy", async function () {

        await vault.connect(user).deposit({ value: ethers.parseEther("1") });
        await vault.connect(user).mint(
            ethers.parseEther("1200")
        );

        // Crash price to $1000
        await mockFeed.updateAnswer(1000n * 10n ** 8n);

        // Liquidator gets PVUSD
        await stablecoin.connect(user).transfer(
            liquidator.address,
            ethers.parseEther("600")
        );

        await stablecoin.connect(liquidator).approve(
            vault.target,
            ethers.parseEther("600")
        );

        await vault.connect(liquidator).liquidate(
            user.address,
            ethers.parseEther("600")
        );

        const newDebt = await vault.debt(user.address);
        expect(newDebt).to.equal(
            ethers.parseEther("600")
        );
    });

    it("should allow governance to update collateral ratio", async function () {

        await vault.connect(owner).setCollateralRatio(170);

        const ratio = await vault.collateralRatio();
        expect(ratio).to.equal(170);
    });


});

