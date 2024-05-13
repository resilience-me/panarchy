const apiURL = '/node/account/';
const metamaskAccount = document.getElementById('metamaskAccount');
const accountInput = document.getElementById('accountInput');
const responseDisplay = document.getElementById('response');
const addressInput = document.getElementById('addressInput');
const loadAddressButton = document.getElementById('loadAddressButton');

async function fetchAccountInfo(address) {
    try {
        const response = await fetch(apiURL + address);
        const data = await response.json();
        responseDisplay.innerHTML = syntaxHighlight(data);
        responseDisplay.style.display = 'block'
    } catch (error) {
        console.error('Error fetching account info:', error);
        responseDisplay.innerText = 'Error fetching account info.';
    }
}

function syntaxHighlight(json) {
    json = JSON.stringify(json, undefined, 2);
    json = json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return json.replace(/("(\\u[a-zA-F0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)/g, function(match) {
        let cls = 'json-value';
        if (/^"/.test(match)) {
            if (/:$/.test(match)) {
                cls = 'json-key';
            } else {
                cls = 'json-string';
            }
        } else if (/true|false/.test(match)) {
            cls = 'json-boolean';
        } else if (/null/.test(match)) {
            cls = 'json-null';
        }
        return '<span class="' + cls + '">' + match + '</span>';
    });
}

function handleAccountChange(accounts) {
    if (accounts.length > 0) {
        metamaskAccount.style.display = 'block';
        metamaskAccount.innerText = `Logged in with MetaMask. Account: ${accounts[0]}`;
        accountInput.style.display = 'none';
        fetchAccountInfo(accounts[0], true);
    }
}

function resetDisplay() {
    metamaskAccount.innerText = '';
    metamaskAccount.style.display = 'none'
    accountInput.style.display = 'block';
    responseDisplay.innerText = '';
    responseDisplay.style.display = 'none'
}

function isValidAddress(address) {
    const regex = /^(0x)?[0-9a-fA-F]{40}$/;
    return regex.test(address);
}

addressInput.addEventListener('input', () => {
    loadAddressButton.disabled = !isValidAddress(addressInput.value.trim());
});

loadAddressButton.addEventListener('click', () => {
    const address = addressInput.value.trim();
    if (isValidAddress(address)) {
        fetchAccountInfo(address);
    } else {
        console.error('Invalid address:', address);
    }
});

document.getElementById('loginButton').addEventListener('click', async () => {
    if (window.ethereum) {
        try {
            const accounts = await window.ethereum.request({ method: 'eth_accounts' });
            handleAccountChange(accounts);
        } catch (error) {
            console.error('User denied account access:', error);
        }
    } else {
        console.log('MetaMask is not installed!');
    }
});

window.ethereum?.on('accountsChanged', (accounts) => {
    resetDisplay();
    handleAccountChange(accounts);
});

function readAddressFromURL() {
    const urlParams = new URLSearchParams(window.location.search);
    const address = urlParams.get('address');
    if (isValidAddress(address)) {
        document.getElementById('addressInput').value = address;
        loadAddressButton.disabled = false;
        fetchAccountInfo(address, false);
        return true;
    }
    return false;
}

window.addEventListener('load', async () => {
    if(!readAddressFromURL()) {
        if (window.ethereum) {
            try {
                const accounts = await window.ethereum.request({ method: 'eth_accounts' });
                handleAccountChange(accounts);
            } catch (error) {
                console.error('Error fetching accounts:', error);
            }
        } else {
            console.log('MetaMask is not available.');
        }
    }
});
