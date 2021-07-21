const ZorroStrategy = artifacts.require("ZorroStrategy");

contract("ZorroStrategy", async accounts => {
    it.skip('Should add a new LP token to a strategy', async () => {
        const instance = await ZorroStrategy.deployed();
        await instance.addLPContractToStrategy(accounts[1], 'stablecoin', accounts[2], accounts[3], accounts[4], accounts[5], 0);
        const addedContract = await instance.lpContracts('stablecoin', 0);
        assert.equal(addedContract.ammContractAddress, accounts[1]);
        // TODO - checks before and after
        // TODO - does not add more than one
        // TODO - doe snot add duplicates
    });

    it.skip('Removes an added LP token from a strategy', async () => {
        // TODO - normal case
        // TODO - start, end, and middle of an array
        // TODO - multiple strategies
        // TODO - try to remove a contract that doesn't exist
        // TODO - try to remove a contract under a strategy that doesn't exist
    });

    it('Invests in a strategy', async () => {
        const instance = await ZorroStrategy.deployed();
        await instance.addLPContractToStrategy(accounts[1], 'stablecoin', accounts[2], accounts[3], accounts[4], accounts[5], 0);
        const res = await instance.invest('stablecoin', {value: 1e18});
        assert.ok(true);
    })
});
