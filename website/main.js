const apiURL = '/node/account/';
const metamaskAccount = document.getElementById('metamaskAccount');
const accountInput = document.getElementById('accountInput');
const responseDisplay = document.getElementById('response');
const addressInput = document.getElementById('addressInput');
const loadAddressButton = document.getElementById('loadAddressButton');

var scheduleUtil = {
    dateAndTimeString(eventDate) {
	return eventDate.toLocaleString("en-US", {
	    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
	    hour: '2-digit', minute: '2-digit', second: '2-digit', timeZoneName: 'short'
	});
    },
    pseudonymEventString(data) {
	const time = parseInt(data.schedule.nextSchedule.pseudonymEvent, 10);
	return this.dateAndTimeString(new Date(time * 1000));
    },
    nextPeriodString(data) {
	const time = parseInt(data.schedule.nextSchedule.toSeconds, 10);
	return this.dateAndTimeString(new Date(time * 1000));
    },
    halftimeString(data) {
	const weeksInSeconds = 60 * 60 * 24 * 7;
	const time = parseInt(data.schedule.currentSchedule.toSeconds, 10) + weeksInSeconds * 2;
	return this.dateAndTimeString(new Date(time * 1000));
    }
}

var formats = {
    isHex(input, length) {
	return new RegExp(`^(0x)?[0-9A-Fa-f]{${length}}$`).test(input);
    },
    isValidAddress(address) {
	return this.isHex(address, 40);
    },
    is32ByteHex(input) {
	return this.isHex(input, 64);
    }
}

function userStringForLoggedInOrNot(isMetamask, address, secondWordForYou = '', secondWordForAddress = '') {
    return isMetamask ? `You${secondWordForYou}` : `<span class="truncated-address">${address}</span>${secondWordForAddress}`;
}

var helper = {
    isCommitSet(data) {
	return data.contracts.bitpeople.currentData.account.commit != '0x0000000000000000000000000000000000000000000000000000000000000000';
    },
    isRegistered(data) {
	return this.isCommitSet(data);
    },
    isOptIn(data) {
	return data.contracts.bitpeople.currentData.account.court.id > 0;
    },
    inPseudonymEvent(data) {
	return data.contracts.bitpeople.previousData.account.nym.id != 0;
    },
    hasVerified(data) {
	const previousNymID = data.contracts.bitpeople.previousData.account.nym.id;
	const previousPair = data.contracts.bitpeople.previousData.account.pair;
	return previousPair.verified[previousNymID%2];
    },
    pairVerified(data) {
	const previousPair = data.contracts.bitpeople.previousData.account.pair;
	return previousPair.verified[0] && previousPair.verified[1];
    },
    isVerified(data) {
	return data.contracts.bitpeople.previousData.account.verified;
    },
    isPaired(data) {
	return data.contracts.bitpeople.currentData.account.pair.partner != '0x0000000000000000000000000000000000000000';
    },
    isOptInJudge(data) {
	const pairs = data.contracts.bitpeople.currentData.global.registryLength / 2;
	const courts = data.contracts.bitpeople.currentData.global.courts;
	const pairID = Math.floor((data.contracts.bitpeople.currentData.account.nym.id + 1) / 2);
	let courtsToJudge = 0;
	if(courts > pairs) courtsToJudge++;
	const secondRotationCourts = courts - pairs*courtsToJudge;
	courtsToJudge += (pairID <= secondRotationCourts) ? 1 : 0;
	return courtsToJudge;
    },
    courtPairMemberShuffled(data) {
	return data.contracts.bitpeople.currentData.account.court.judges[0] != '0x0000000000000000000000000000000000000000' || data.contracts.bitpeople.currentData.account.court.judges[1] != '0x0000000000000000000000000000000000000000'
    }
};

async function fetchAccountInfo(address, bitpeople) {
    try {
	const isMetamask = bitpeople instanceof Bitpeople;
        const response = await fetch(apiURL + address);
        const data = await response.json();

        responseDisplay.style.display = 'block';
	    
        if (data.contracts.bitpeople.currentData.account.proofOfUniqueHuman) {
            responseDisplay.innerHTML = userStringForLoggedInOrNot(isMetamask, address, ' have', ' has') + ' a proof-of-unique-human';
        } else if (helper.inPseudonymEvent(data)) {
            handlePseudonymEvent(address, data, isMetamask, bitpeople);
        } else if (helper.isRegistered(data)) {
            handleRegistrationStatus(address, data, isMetamask, bitpeople);
        } else if (helper.isOptIn(data)) {
            handleOptInStatus(address, data, isMetamask);
	} else {
            handleOtherScenarios(address, data, isMetamask, bitpeople);
        }
    } catch (error) {
        console.error('Error fetching account info:', error);
    }
}

function validateCourtAddressInput() {
    const input = document.getElementById('courtAddressInput');
    const judgeButton = document.getElementById('judgeButton');
    judgeButton.disabled = !formats.isValidAddress(input.value.trim());
}

function handlePseudonymEvent(address, data, isMetamask, bitpeople) {
    responseDisplay.innerHTML = userStringForLoggedInOrNot(isMetamask, address, ' have', ' has') + ' participated in the pseudonym event';

    if (!helper.hasVerified(data)) {
	if (isMetamask) {
	    responseDisplay.innerHTML += '<p>Verify the other person in your pair</p>';
	    const verifyBtn = document.createElement('button');
	    verifyBtn.textContent = 'Verify';
	    verifyBtn.addEventListener('click', () => bitpeople.verify());
	    responseDisplay.appendChild(verifyBtn);
	} else {
	    responseDisplay.innerHTML += '<p>Log in with Metamask to verify the other person in the pair</p>';
	}
    } else if (helper.isVerified(data)) {
	if(data.schedule.currentSchedule.quarter < 2) {
	    if (isMetamask) {
		responseDisplay.innerHTML += [
		    '<p>You are verified and have collected your tokens</p>',
		    '<p>If you were assigned to judge a "court", input their address and press judge</p>'
		].join('');
		const inputField = document.createElement('input');
		inputField.type = 'text';
		inputField.id = 'courtAddressInput';
		inputField.placeholder = 'Enter "court" address here';
		inputField.size = '42';
		responseDisplay.appendChild(inputField);
		
		const judgeButton = document.createElement('button');
		judgeButton.id = 'judgeButton';
		judgeButton.textContent = 'Judge';
		judgeButton.disabled = true;
		judgeButton.addEventListener('click', () => judge(document.getElementById('courtAddressInput').value));
		responseDisplay.appendChild(judgeButton);
		
		inputField.oninput = validateCourtAddressInput;
	    } else {
		responseDisplay.innerHTML += [
		'<p>The account is verified and has collected its tokens</p>',
		'<p>To judge any "courts" it was assigned to judge, log in with Metamask</p>'
		].join('');
	    }
	} else if (data.schedule.currentSchedule.quarter == 2 && isCommitSet(data)) {
	    if (isMetamask) {
		responseDisplay.innerHTML += '<p>Your pair is verified. Reveal your random number so that you can claim your proof-of-unique-human after that</p>';
		const input = document.createElement("input");
		input.type = "text";
		input.value = "Enter your random number here";
		input.size = 64;
		const button = document.createElement("button");
		button.textContent = "Submit";
		button.disabled = true;
		input.addEventListener('input', function() {
		    if (formats.is32ByteHex(input.value)) {
		        button.disabled = false;
		    } else {
		        button.disabled = true;
		    }
		});
		button.addEventListener("click", function() {
		    const randomNumber = input.value;
		    bitpeople.revealHash(randomNumber);
		});
		responseDisplay.appendChild(input);
		responseDisplay.appendChild(button);
	} else {
	    responseDisplay.innerHTML += `<p>Log in with Metamask to reveal the account's random number and claim its proof-of-unique-human</p>`;
	}
    }
    } else if (helper.pairVerified(data)) {
	if (isMetamask) {
	    responseDisplay.innerHTML += '<p>Your pair is verified. Collect your tokens</p>';
	    const collectTokensBtn = document.createElement('button');
	    collectTokensBtn.textContent = 'Collect tokens';
	    collectTokensBtn.addEventListener('click', () => bitpeople.nymVerified());
	    responseDisplay.appendChild(collectTokensBtn);
	} else {
	    responseDisplay.innerHTML += '<p>The pair the account is in is verified. Log in with Metamask to collect the tokens</p>';
	}
    }
}

function setupShuffleButton() {
    const shuffleBtn = document.createElement('button');
    shuffleBtn.textContent = 'Shuffle';
    shuffleBtn.addEventListener('click', () => bitpeople.shuffle());
    responseDisplay.appendChild(shuffleBtn);
}

function handleRegistrationStatus(address, data, isMetamask, bitpeople) {
    responseDisplay.innerHTML = userStringForLoggedInOrNot(isMetamask, address, ' are', ' is') + ' registered for the upcoming event on ' + scheduleUtil.pseudonymEventString(data);

    if (data.schedule.currentSchedule.quarter == 3) {
	if(!data.contracts.bitpeople.currentData.account.shuffler) {
	    responseDisplay.innerHTML += '<p>It is time to shuffle. After you have shuffled, you can contact the person in your pair to agree on a video channel. </p>';
            setupShuffleButton();
	} else if (helper.isPaired(data)) {
            if (isMetamask) {
                const baseUrl = "https://chat.blockscan.com/";
                const path = "index";
                const url = new URL(path, baseUrl);
                url.searchParams.append('a', data.contracts.bitpeople.currentData.account.pair.partner);
		responseDisplay.innerHTML += '<p>Contact the person in your pair to agree on a video channel: ' + '<a href="' + url.href + '">' + url.href + '</a></p>';
		const courtsToJudgeCount = helper.isOptInJudge(data);
		if (courtsToJudgeCount > 0) {
		    let courtDynamicText = 'a "court"';
		    if (courtsToJudgeCount == 2) {
		        courtDynamicText = 'two "courts"';
		    }
		    responseDisplay.innerHTML += `<p>You have been assigned to judge ${courtDynamicText}. They can contact you on ${baseUrl} too.</p>`;
		}
	    } else {
                responseDisplay.innerHTML += '<p>Log in with Metamask to contact the person in the pair</p>';
            }
        } else if (isMetamask) {
	    responseDisplay.innerHTML += '<p>You are not paired yet. Wait until shuffling is complete. You can shuffle again to speed things up. </p>';
            setupShuffleButton();
        }
    }
}

function handleOptInStatus(address, data, isMetamask) {
    responseDisplay.innerHTML = userStringForLoggedInOrNot(isMetamask, address, ' have', ' has') + ' opted-in for the upcoming event on ' + scheduleUtil.pseudonymEventString(data);
    if (data.schedule.currentSchedule.quarter == 3 && helper.courtPairMemberShuffled(data)) {
	if (isMetamask) {
	    responseDisplay.innerHTML += '<p>Contact your "court" to agree on a video channel:</p>';
	    const baseUrl = "https://chat.blockscan.com/";
	    const path = "index";

	    data.contracts.bitpeople.currentData.account.court.judges.forEach(pair => {
		if (pair !== '0x0000000000000000000000000000000000000000') {
		    const url = new URL(path, baseUrl);
		    url.searchParams.append('a', pair);
		    responseDisplay.innerHTML += `<p><a href="${url.href}">${url.href}</a></p>`;
		}
	    });
	} else {
            responseDisplay.innerHTML += '<p>Log in with Metamask to contact the "court" the account is assigned to</p>';
        }
    }
}

function generateRandomNumber() {
    let randomNumber = "";
    for (let i = 0; i < 64; i++) {
        const randomHexDigit = Math.floor(Math.random() * 16).toString(16);
        randomNumber += randomHexDigit;
    }
    return randomNumber;
}

function handleOtherScenarios(address, data, isMetamask, bitpeople) {
    if (data.contracts.bitpeople.currentData.account.tokens.register > 0) {
        if (data.schedule.currentSchedule.quarter < 2) {
            responseDisplay.innerHTML = userStringForLoggedInOrNot(isMetamask, address) + ' can register for the event';
            if (isMetamask) {
                const randomNumber = generateRandomNumber();

                responseDisplay.innerHTML += [
                    '<p>To register, you need to contribute a random number to the random number generator.</p>',
                    `<p>This site has generated one for you: <input type="text" value="${randomNumber}" size="64" style="max-width: 100%; box-sizing: border-box;" readonly></p>`,
                    '<p>Write it down, you will need it to claim your proof-of-unique-human later.</p>'
                ].join('');
		    
                const registerBtn = document.createElement('button');
                registerBtn.textContent = 'Register';
                registerBtn.addEventListener('click', () => bitpeople.register(randomNumber));
                responseDisplay.appendChild(registerBtn);
            } else {
		responseDisplay.innerHTML += [
		    '<p>Registration closes ' + scheduleUtil.halftimeString(data) + '</p>',
		    '<p>Log in with Metamask to register</p>'
		].join('');
            }
        } else {
            responseDisplay.innerText = 'The next registration period opens on: ' + scheduleUtil.nextPeriodString(data);
        }
    } else if (data.contracts.bitpeople.currentData.account.tokens.optIn > 0) {
        if (data.schedule.currentSchedule.quarter < 2) {
            responseDisplay.innerHTML = userStringForLoggedInOrNot(isMetamask, address, ' have', ' has') + ' an opt-in token and can opt-in to the network';
            if (isMetamask) {
                const optInDiv = document.createElement('div');
                optInDiv.className = 'opt-in-btn';
                
                const optInBtn = document.createElement('button');
                optInBtn.textContent = 'Opt-in';
                optInBtn.addEventListener('click', () => bitpeople.optIn());
                optInDiv.appendChild(optInBtn);
                
                responseDisplay.appendChild(optInDiv);
            } else {
		responseDisplay.innerHTML += [
		    '<p>The opt-in period closes ' + scheduleUtil.halftimeString(data) + '</p>',
                    '<p>Log in with Metamask to opt-in</p>'
		].join('');
            }
        } else {
            responseDisplay.innerText = 'The next opt-in period opens on: ' + scheduleUtil.nextPeriodString(data);
        }
    } else {
        responseDisplay.innerHTML = userStringForLoggedInOrNot(isMetamask, address, ' need', ' needs') + ' a register token or an opt-in token to participate in the event';
    }
}

async function fromAndGasPrice(account, web3) {
	const gasPrice = await web3.eth.getGasPrice();
	return {
            from: account,
            gasPrice: gasPrice
        };
}

function updateAddress(newAddress) {
    let newUrl = `${window.location.protocol}//${window.location.host}${window.location.pathname}`
    if (newAddress) {
        newUrl += `?address=${newAddress}`;
    }
    history.pushState({address: newAddress}, "", newUrl);
    adjustLogo();
}

async function handleAccountChange(accounts) {
    if (accounts.length > 0) {
        metamaskAccount.style.display = 'block';
        metamaskAccount.innerHTML = `Logged in with MetaMask. Account: <span class="truncated-address">${accounts[0]}</span>`;
        accountInput.style.display = 'none';
        const web3 = new Web3(window.ethereum);
        const txObj = await fromAndGasPrice(accounts[0], web3);
        const bitpeople = new Bitpeople(web3, txObj);
        await fetchAccountInfo(accounts[0], bitpeople);
        updateAddress();
    }
}

function resetDisplay() {
    metamaskAccount.innerText = '';
    metamaskAccount.style.display = 'none'
    accountInput.style.display = 'block';
    responseDisplay.innerText = '';
    responseDisplay.style.display = 'none'
}

function setupEventListeners() {
    addressInput.addEventListener('input', () => {
        loadAddressButton.disabled = !formats.isValidAddress(addressInput.value.trim());
    });

    loadAddressButton.addEventListener('click', async () => {
        const address = addressInput.value.trim();
        if (formats.isValidAddress(address)) {
            await fetchAccountInfo(address);
            updateAddress(address);
        } else {
            console.error('Invalid address:', address);
        }
    });

    document.getElementById('loginButton').addEventListener('click', async () => {
        if (window.ethereum) {
            try {
                const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
            } catch (error) {
                console.error('User denied account access:', error);
            }
        } else {
            console.log('MetaMask is not installed!');
        }
    });

    window.ethereum?.on('accountsChanged', async (accounts) => {
        resetDisplay();
        await handleAccountChange(accounts);
    });
}

async function readAddressFromURL() {
    const urlParams = new URLSearchParams(window.location.search);
    const address = urlParams.get('address');
    if (formats.isValidAddress(address)) {
        document.getElementById('addressInput').value = address;
        loadAddressButton.disabled = false;
        await fetchAccountInfo(address);
        return true;
    }
    return false;
}

window.addEventListener('load', async () => {
    setupEventListeners();
    if(!await readAddressFromURL()) {
        if (window.ethereum) {
            try {
                const accounts = await window.ethereum.request({ method: 'eth_accounts' });
                await handleAccountChange(accounts);
            } catch (error) {
                console.error('Error fetching accounts:', error);
            }
        } else {
            console.log('MetaMask is not available.');
        }
    }
    adjustLogo();    
});
