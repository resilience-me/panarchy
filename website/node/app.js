const express = require('express');
const app = express();
const Web3 = require('web3');
const Account = require('./src/account');

// Define a route to handle requests for account information
app.get('/node/account/:address', async (req, res) => {
    const address = req.params.address;
    const account = new Account(address);
    await account.initScheduleAndContracts();
    // Get parameters for the account

    const parameters = await account.getParameters();

    // Send the parameters as a JSON response
    res.json(parameters);
});

// Start the server
const port = process.env.PORT || 3000;
app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
