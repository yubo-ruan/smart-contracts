const { expect } = require("chai");
const { BigNumber } = require("ethers");


describe("TrustToken", function() {
  
  beforeEach(async function () {
    [owner, a1, a2, ...addrs] = await ethers.getSigners();
    admin = owner.address;
    trusttoken = await (await ethers.getContractFactory("TrustToken")).deploy();
  });
  it("Should return the right balance after minting", async function() {
    await trusttoken.mint(a1.address,1e8);
    const bal = await trusttoken.balanceOf(a1.address);
    expect(bal).to.equal(BigNumber.from(1e8));
  });
  it("Should return the right balance after burning", async function() {
    await trusttoken.mint(admin,1e8);
    await trusttoken.delegate(a1.address);
    const a1Bal = await trusttoken.balanceOf(a1.address);
    const a1Vote = await trusttoken.getCurrentVotes(a1.address);
    expect(a1Bal).to.be.equal('0');
    expect(a1Vote).to.be.equal('100000000');
  });
});
