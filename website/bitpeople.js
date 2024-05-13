const bitpeopleABI = [
	{
		"inputs": [],
		"name": "optIn",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "bytes32",
				"name": "_commit",
				"type": "bytes32"
			}
		],
		"name": "register",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "shuffle",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "bytes32",
				"name": "preimage",
				"type": "bytes32"
			}
		],
		"name": "revealHash",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	}
]

const bitpeopleAddress = "0x0000000000000000000000000000000000000010";

class Bitpeople {
    constructor(web3, txObj) {
        this.web3 = web3;
        this.bitpeopleContract = new web3.eth.Contract(bitpeopleABI, bitpeopleAddress);
        this.txObj = txObj;
    }

    async register(randomNumber) {
        try {
            const randomHash = this.web3.utils.sha3('0x' + randomNumber);
            const result = await this.bitpeopleContract.methods.register(randomHash).send(this.txObj);
            console.log('Registration successful:', result);
            responseDisplay.innerHTML = `You are registered for the upcoming pseudonym event. Remember to write down your random number <span class="truncated-hex">${randomNumber},</span> you will need it to claim your proof of unique human later.`;
        } catch (error) {
            responseDisplay.innerText = 'Error registering';
            console.error('Error registering:', error);
        }
    }

    async optIn() {
        try {
            const result = await this.bitpeopleContract.methods.optIn().send(this.txObj);
            console.log('Opt-in successful:', result);
            responseDisplay.innerText = 'You have opted-in to BitPeople for the upcoming pseudonym event.';
        } catch (error) {
            responseDisplay.innerText = 'Error opting in';
            console.error('Error opting in:', error);
        }
    }

    async shuffle() {
        try {
            const result = await this.bitpeopleContract.methods.shuffle().send(this.txObj);
            console.log('Shuffle successful:', result);
            responseDisplay.innerText = 'Shuffled one person in the population';
        } catch (error) {
            responseDisplay.innerText = 'Error shuffling';
            console.error('Error shuffling:', error);
        }
    }

    async verify() {
        try {
            const result = await this.bitpeopleContract.methods.verify().send(this.txObj);
            console.log('Verify successful:', result);
            responseDisplay.innerText = 'Verified the other person in your pair';
        } catch (error) {
            responseDisplay.innerText = 'Error verifying';
            console.error('Error verifying:', error);
        }
    }

    async judge(court) {
        try {
            const result = await this.bitpeopleContract.methods.judge(court).send(this.txObj);
            console.log('Judge court successful:', result);
            responseDisplay.innerText = `You have verified the "court" for ${court}`;
        } catch (error) {
            responseDisplay.innerText = 'Error judging court';
            console.error('Error judging court:', error);
        }
    }

    async nymVerified() {
        try {
            const result = await this.bitpeopleContract.methods.nymVerified().send(this.txObj);
            console.log('Token collection successful:', result);
            responseDisplay.innerText = 'Collected one nym token and one border token';
        } catch (error) {
            responseDisplay.innerText = 'Error collecting tokens';
            console.error('Error collecting tokens:', error);
        }
    }
    async revealHash(preimage) {
        try {
            const result = await this.bitpeopleContract.methods.revealHash(preimage).send(this.txObj);
            console.log('Reveal preimage successful:', result);
            responseDisplay.innerText = 'Revealed your random number. You can now claim your proof-of-unique-human';
        } catch (error) {
            responseDisplay.innerText = 'Error revealing random number tokens';
            console.error('Error revealing random number:', error);
        }
    }
}
