const { Web3 } = require('web3');
const bitpeopleABI = require('./bitpeopleABI');
const bitpeopleAddress = "0x0000000000000000000000000000000000000010";

class Local {
    constructor(web3) {
        this.web3 = web3;
        this.contracts = {}
        this.contracts.bitpeopleContract = new this.web3.eth.Contract(bitpeopleABI, bitpeopleAddress);
        // Add other contracts here
    }
}

class Account {
    constructor(address) {
        this.local = new Local(new Web3('http://localhost:8546'));
        this.address = this.local.web3.utils.toChecksumAddress(address);
    }
    async initScheduleAndContracts() {
        try {
            await this.loadSchedule();
            this.bitpeople = new Bitpeople(this.schedule);
            // Add other contracts here, e.g., this.election = new Election();
        } catch (error) {
            console.error('Failed to initialize schedule and contracts:', error);
            throw new Error("Error initializing schedule and contracts.");
        }
    }
    async loadSchedule() {
        try {
            const methods = this.local.contracts.bitpeopleContract.methods;
            const schedule = await methods.schedule().call();
            const [toSeconds, quarter, hour, pseudonymEvent] = await Promise.all([
                methods.toSeconds(schedule).call(),
                methods.quarter(schedule).call(),
                methods.hour(schedule).call(),
                methods.pseudonymEvent(schedule).call()
            ]);
    
            const nextSchedule = Number(schedule) + 1;
            const [nextToSeconds, nextHour, nextPseudonymEvent] = await Promise.all([
                methods.toSeconds(nextSchedule).call(),
                methods.hour(nextSchedule).call(),
                methods.pseudonymEvent(nextSchedule).call()
            ]);
    
            this.schedule = {
                currentSchedule: {
                    schedule: Number(schedule),
                    toSeconds: Number(toSeconds),
                    quarter: Number(quarter),
                    hour: Number(hour),
                    pseudonymEvent: Number(pseudonymEvent)
                },
                nextSchedule: {
                    schedule: Number(nextSchedule),
                    toSeconds: Number(nextToSeconds),
                    hour: Number(nextHour),
                    pseudonymEvent: Number(nextPseudonymEvent)
                }
            };
        } catch (error) {
            console.error('Failed to load schedule:', error);
            throw new Error("Error loading schedule.");
        }
    }

    async getParameters() {
        try {
            const bitpeople = await this.bitpeople.loadParameters(this.local.contracts.bitpeopleContract.methods, this.address); // Load contract-specific parameters
            return {
                schedule: this.schedule,
                contracts: {
                    bitpeople: bitpeople,
                    // Add other contract parameters here
                }
            };
        } catch (error) {
            console.error('Failed to get account data:', error);
            throw new Error("Error getting account data.");
        }
    }
}

class Bitpeople {

    constructor(schedule) {
        this.schedule = schedule;
    }

    async loadGlobal(schedule, methods) {
        try {
            const [seed, registryLength, shuffled, courts, population, permits] = await Promise.all([
                methods.seed(schedule).call(),
                methods.registryLength(schedule).call(),
                methods.shuffled(schedule).call(),
                methods.courts(schedule).call(),
                methods.population(schedule).call(),
                methods.permits(schedule).call()
            ]);
            return {
                seed: Number(seed),
                registryLength: Number(registryLength),
                shuffled: Number(shuffled),
                courts: Number(courts),
                population: Number(population),
                permits: Number(permits)
            };
        } catch (error) {
            console.error('Failed to load global data:', error);
            throw new Error("Error loading global data.");
        }
    }

    async loadAccount(schedule, global, registrationEnded, methods, address) {
        try {
            const nymData = await methods.nym(schedule, address).call();
            const nym = {
                id: Number(nymData.id),
                verified: nymData.verified
            };

            const [shuffler, proofOfUniqueHuman, commit] = await Promise.all([
                methods.shuffler(schedule, address).call(),
                methods.proofOfUniqueHuman(schedule, address).call(),
                methods.commit(schedule, address).call()
            ]);
    
            const pairID = Math.floor((nym.id + 1) / 2);
            const pairData = await methods.pair(schedule, pairID).call();
            let pair = {
                partner: '0x0000000000000000000000000000000000000000',
                verified: pairData.verified,
                disputed: pairData.disputed
            }
            const pairedWithID = pairID * 2 - 1 + (nym.id % 2 ^ 1);
            if (pairedWithID != 0 && global.shuffled >= pairedWithID) {
                pair.partner = await methods.registry(schedule, pairedWithID - 1).call();
            }
            const courtData = await methods.court(schedule, address).call();
            let court = {
                id:  Number(courtData.id),
                judges: ['0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000'],
                verified: courtData.verified
            };
            const registeredPairs = Math.floor(global.registryLength / 2);
            if (court.id > 0 && registeredPairs > 0 && registrationEnded) {
                const courtPairID = court.id != 0 ? 1 + (court.id - 1) % registeredPairs : 0;
                const courtPairNym1 = courtPairID * 2 - 1;
                const courtPairNym2 = courtPairID * 2;
                if (global.shuffled >= courtPairNym2) {
                    court.judges[1] = await methods.registry(schedule, courtPairNym2 - 1).call();
                }
                if (global.shuffled >= courtPairNym1) {
                    court.judges[0] = await methods.registry(schedule, courtPairNym1 - 1).call();
                }
            }
    
            return {
                nym,
                shuffler,
                pair,
                court,
                proofOfUniqueHuman,
                commit,
            };
        } catch (error) {
            console.error('Failed to load account data:', error);
            throw new Error("Error loading account data.");
        }
    }

    loadEmpty() {
        return {
            global: {
                seed: 0,
                registryLength: 0,
                shuffled: 0,
                courts: 0,
                population: 0,
                permits: 0
            },
            account: {
                nym: {
                    id: 0,
                    verified: false
                },
                shuffler: false,
                pair: {
                    partner: '0x0000000000000000000000000000000000000000',
                    verified: [false,false],
                    disputed: false
                },
                court: {
                    id: 0,
                    pair: ['0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000'],
                    verified: [false, false]
                },
                proofOfUniqueHuman: false,
                commit: '0x0000000000000000000000000000000000000000000000000000000000000000',
            }
        };
    }

    async loadPreviousData(schedule, methods, address) {
        try {
            if(schedule > 0) {
                const global = await this.loadGlobal(schedule - 1, methods);
                const registrationEnded = true;
                const account = await this.loadAccount(schedule, global, registrationEnded, methods, address);
                return {
                    global,
                    account
                };
            }
            return this.loadEmpty();
        } catch (error) {
            console.error('Failed to load previous data:', error);
            throw new Error("Error loading previous data.");
        }
    }
    async loadCurrentData(schedule, methods, address) {
        try {
            const global = await this.loadGlobal(schedule, methods);
            const registrationEnded = this.schedule.currentSchedule.quarter > 1;
            const [account, proofOfUniqueHumanToken, registerToken, optInToken, borderVoteToken] = await Promise.all([
                this.loadAccount(schedule, global, registrationEnded, methods, address),
                methods.balanceOf(schedule, 0, address).call(),
                methods.balanceOf(schedule, 1, address).call(),
                methods.balanceOf(schedule, 2, address).call(),
                methods.balanceOf(schedule, 3, address).call()
            ]);
            return {
                global,
                account: {
                    ...account,
                    tokens: {
                        proofOfUniqueHuman: Number(proofOfUniqueHumanToken),
                        register: Number(registerToken),
                        optIn: Number(optInToken),
                        borderVote: Number(borderVoteToken)
                    }
                }
            };
        } catch (error) {
            console.error('Failed to load current data:', error);
            throw new Error("Error loading current data.");
        }
    }
    async loadNextData(schedule, methods, address) {
        try {
            const [proofOfUniqueHuman, population] = await Promise.all([
                methods.proofOfUniqueHuman(schedule + 1, address).call(),
                methods.population(schedule + 1).call()
            ]);

            return {
                global: {
                    population: Number(population)
                },
                account: {
                    proofOfUniqueHuman
                }
            };
        } catch (error) {
            console.error('Failed to load next data:', error);
            throw new Error("Error loading next data.");
        }
    }
    async loadParameters(methods, address) {
        try {
            const schedule = this.schedule.currentSchedule.schedule;
            const [previousData, currentData, nextData] = await Promise.all([
                this.loadPreviousData(schedule, methods, address),
                this.loadCurrentData(schedule, methods, address),
                this.loadNextData(schedule, methods, address)
            ]);
            return {
                previousData,
                currentData,
                nextData
            };
        } catch (error) {
            console.error('Error loading parameters:', error);
            throw new Error("Error loading parameters.");
        }
    }
}
module.exports = Account;
