import { Blockchain,  SandboxContract, TreasuryContract } from '@ton/sandbox';
import {  Slice, toNano } from '@ton/core';
import { LingoRaffle } from '../wrappers/TonTut';
import '@ton/test-utils';
import { createHash } from 'node:crypto';
const { keyPairFromSeed, sign } = require('ton-crypto');
const { beginCell, Address } = require('ton-core');
// import { keyPairFromSeed, sign } from 'ton-crypto';
// import { beginCell, Address }  from 'ton-core';

function serializeData(
    raffleId: bigint,
    account: TreasuryContract,
    amount: bigint,
    nonce: bigint,
    randomness: bigint,
    publicKey: Buffer
) {

    const tonAddress = Address.parse(account.address.toString());
    const publicKeyCell = beginCell()
    .storeBuffer(publicKey) // Store the public key in its own cell
    .endCell();

    const randomnessCell = beginCell()
    .storeUint(randomness, 256) // Store the randomness in its own cell (256 bits)
    .endCell();

    const cell = beginCell()
        .storeUint(raffleId, 256) // Assume 256 bits for BigInt
        .storeAddress(tonAddress) // Store the player's TON address
        .storeUint(amount, 256) // Assume 256 bits for BigInt
        .storeUint(nonce, 64) // Assume 256 bits for BigInt
        .storeRef(randomnessCell)
        .storeRef(publicKeyCell) // Assume 256 bits for randomness
        .endCell();

    return cell;
}
async function generateKeyPair() {
    const seed = Buffer.from('0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef', 'hex');

    const keyPair = keyPairFromSeed(seed);

    return keyPair;
}

async function signRaffleData(raffleData: any) {
    const keyPair = await generateKeyPair();

    const raffleId = raffleData.raffleId;
    const account = raffleData.account;
    const amount = raffleData.amount;
    const nonce = raffleData.nonce;
    const randomness = raffleData.randomness;

    const cell = serializeData(raffleId, account, amount, nonce, randomness, keyPair.publicKey);

    const dataHash = cell.hash();

    const signature = await sign(dataHash, keyPair.secretKey);

    return {
        signature,
        publicKey: keyPair.publicKey
    };
}

describe('TonTut', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let tonTut: SandboxContract<LingoRaffle>;
    let player1: SandboxContract<TreasuryContract>;
    let player2: SandboxContract<TreasuryContract>;
    let signer: SandboxContract<TreasuryContract>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        deployer = await blockchain.treasury('deployer');
        player1 = await blockchain.treasury('player1');
        player2 = await blockchain.treasury('player2');
        signer = await blockchain.treasury('signer');
        const keyPair = await generateKeyPair();
        const publicKey = BigInt('0x'+keyPair.publicKey.toString('hex'));

        tonTut = blockchain.openContract(await LingoRaffle.fromInit(1n, deployer.address,publicKey));
        const deployResult = await tonTut.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 1n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: tonTut.address,
            deploy: true,
            success: true,
        });
    });

    // describe('Basic functionality', ()=>{
    //     it('should deploy', async () => {
    //         // the check is done inside beforeEach
    //         // blockchain and tonTut are ready to use
    //     });
    //     it('should change signer', async () => {
    //         const newSigner = await blockchain.treasury('newSigner');
    
    //         const signerBefore = await tonTut.getOwner();
            
    //         expect(signerBefore.toString()).toBe(deployer.address.toString());
    
    //         const changeOwnerResult = await tonTut.send(
    //             deployer.getSender(),
    //             {
    //                 value: toNano('0.05'),
    //             },
    //             {
    //                 $$type: "ChangeSignerMessage",
    //                 newSigner: newSigner.address,
    //             }
    //         );
    
    //         expect(changeOwnerResult.transactions).toHaveTransaction({
    //             from: deployer.address,
    //             to: tonTut.address,
    //             success: true,
    //         });
    
    //         const signerAfter = await tonTut.getGetSigner();
    
    //         expect(signerAfter).toEqualAddress(newSigner.address);
    //     });
    // })
    // describe('Tree functionality', ()=>{
    //     // it('correctly inserts nodes', async () => {});
    //     // it('correctly getting nodes', async () => {});
    //     // it('correctly getting by point on interval', async () => {});
    //     // it('correctly handles non existen account', async () => {});
    //     it('should insert value and retrieve it', async () => {
    //         // 1. create new raffle
    //         // 2. run getRaffleTickets
    //         // 3. expect getAccountValue = value from getRaffleTickets

    //         // const amount = 100n;
    
    //         // // Insert the value
    //         // await tonTut.send(
    //         //     deployer.getSender(),
    //         //     {
    //         //         value: toNano('0.05'),
    //         //     },
    //         //     {
    //         //         $$type: 'Insert',
    //         //         account: account,
    //         //         amount: amount,
    //         //     }
    //         // );
    
    //         // // Retrieve the value
    //         // const retrievedValue = await tonTut.getGetTreeAccountValue(account);
    //         // expect(retrievedValue).toBe(amount);
    //     });
    
    //     // it('should correctly calculate intervals', async () => {
    //     //     const account1 = 1n;
    //     //     const account2 = 2n;
    
    //     //     await tonTut.send(deployer.getSender(), { value: toNano('0.05') }, { $$type: 'g', account: account1, amount: 50n });
    //     //     await tonTut.send(deployer.getSender(), { value: toNano('0.05') }, { $$type: 'Insert', account: account2, amount: 100n });
    
    //     //     const pointValue = await intervalTree.getGetByPointOnInterval(75n);
    //     //     expect(pointValue).toBe(account2); // Should return the correct account based on interval
    //     // });
    // })
    describe('Raffle functionality', () => {
        // it('correctly creates new game', async () => {
        //     const randomnessInput = "test";
        //     const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const getRaffle = await tonTut.getGetRaffle(BigInt(0));
        //     expect(getRaffle!.randomnessCommitment).toBe(randomnessCommitment);
        // });
        // it('should correctly apply tickets to players account', async () => {
        //     const randomnessInput = "test1";
        //     const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
            
        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const getTicketsResult = await tonTut.send(
        //         player1.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetRaffleTicketsMessage",
        //             raffleId: BigInt(0),
        //             account: player1.address,
        //             amount: BigInt(1),
        //             nonce: BigInt(0),
        //             randomness: BigInt(100)    
        //         }
        //     );

        //     expect(getTicketsResult.transactions).toHaveTransaction({
        //         from: player1.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const playerAmount = await tonTut.getGetPlayerAmount(BigInt(0), player1.address);
        //     expect(playerAmount).toBe(BigInt(1));
        // });
        // it('should correctly get raffle randomness commitment', async () => {
        //      const randomnessInput = "test";
        //     const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const getRaffleRandomnessCommitment = await tonTut.getGetRaffleRandomnessCommitment(BigInt(0));
        //     expect(getRaffleRandomnessCommitment).toBe(randomnessCommitment);
        // });
        // it('should correctly get raffle current randomness', async () => {
        //      const randomnessInput = "test";
        //     const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const raffleCurrentRandomness = await tonTut.getGetRaffleCurrentRandomness(BigInt(0));
        //     expect(raffleCurrentRandomness).toBe(randomnessCommitment);
        // });
        // it('should correctly get raffle commitment opened after creating new game', async () => {
        //      const randomnessInput = "test";
        //     const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const raffleCommitmentOpened = await tonTut.getGetRaffleCommitmentOpened(BigInt(0));
        //     expect(raffleCommitmentOpened).toBe(false);
        // });
        // it('should correctly get correctly get current raffle total sum', async () => {
        //      const randomnessInput = "test";
        //     const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const getTicketsResult = await tonTut.send(
        //         player1.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetRaffleTicketsMessage",
        //             raffleId: BigInt(0),
        //             account: player1.address,
        //             amount: BigInt(1),
        //             nonce: BigInt(0),
        //             randomness: BigInt(100)    
        //         }
        //     );

        //     expect(getTicketsResult.transactions).toHaveTransaction({
        //         from: player1.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const totalSum = await tonTut.getGetTotalSum(BigInt(0));
        //     expect(totalSum).toBe(BigInt(1));

        //     const getTicketsResult2 = await tonTut.send(
        //         player1.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetRaffleTicketsMessage",
        //             raffleId: BigInt(0),
        //             account: player2.address,
        //             amount: BigInt(14),
        //             nonce: BigInt(0),
        //             randomness: BigInt(100)    
        //         }
        //     );

        //     expect(getTicketsResult2.transactions).toHaveTransaction({
        //         from: player1.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const totalSum2 = await tonTut.getGetTotalSum(BigInt(0));
        //     expect(totalSum2).toBe(BigInt(15));
        // });
        it('should get winner', async () => {
            const randomnessInput = "test";
            const randomnessCommitment = BigInt("0x" + createHash('sha256').update(randomnessInput).digest('hex'));

            const createRaffleResult = await tonTut.send(
                deployer.getSender(),
                {
                    value: toNano('0.05'),
                },
                {
                    $$type: "CreateNewRaffleMessage",
                    randomnessCommitment: randomnessCommitment,
                    key: BigInt(0)
                }
            );

            expect(createRaffleResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: tonTut.address,
                success: true,
            });

            const raffleData = {
                raffleId: BigInt(0),
                account: player1,
                amount: BigInt(1),
                nonce: BigInt(0),
                randomness: BigInt(100)
            }

            const data = await signRaffleData(raffleData);
            const signatureCell: Slice = beginCell().storeBuffer(data.signature).endCell().asSlice();
            console.log(typeof signatureCell);

            const getTicketsResult = await tonTut.send(
                player1.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetRaffleTicketsMessage",
                    raffleId: BigInt(0),
                    account: player1.address,
                    amount: BigInt(1),
                    signature: signatureCell,
                    nonce: BigInt(0),
                    randomness: BigInt(100)    
                }
            );

            // expect(getTicketsResult.transactions).toHaveTransaction({
            //     from: player1.address,
            //     to: tonTut.address,
            //     success: true,
            // });

            // const totalSum = await tonTut.getGetTotalSum(BigInt(0));
            // expect(totalSum).toBe(BigInt(1));

            // const getTicketsResult2 = await tonTut.send(
            //     player1.getSender(),
            //     {
            //         value: toNano('0.15'),
            //     },
            //     {
            //         $$type: "GetRaffleTicketsMessage",
            //         raffleId: BigInt(0),
            //         account: player2.address,
            //         amount: BigInt(14),
            //         nonce: BigInt(0),
            //         randomness: BigInt(100)    
            //     }
            // );

            // expect(getTicketsResult2.transactions).toHaveTransaction({
            //     from: player1.address,
            //     to: tonTut.address,
            //     success: true,
            // });

            // const totalSum2 = await tonTut.getGetTotalSum(BigInt(0));
            // expect(totalSum2).toBe(BigInt(15));
            // const randomnessOpening = randomnessInput;

            // const winnerResult = await tonTut.getGetWinner(BigInt(0));
            // expect(winnerResult).toBeNull();

            // const getWinnerResult = await tonTut.send(
            //     deployer.getSender(),
            //     {
            //         value: toNano('0.15'),
            //     },
            //     {
            //         $$type: "GetWinnerMessage",
            //         raffleId: BigInt(0),
            //         randomnessOpening:randomnessOpening   
            //     }
            // );

            // expect(getWinnerResult.transactions).toHaveTransaction({
            //     from: deployer.address,
            //     to: tonTut.address,
            //     success: true,
            // });

            // const winner = await tonTut.getGetWinner(BigInt(0));

            // expect(winner).not.toBeNull();
        });
        // it('should not get winner with one player', async () => {
        //     const randomnessInput = "test";
        //     const randomnessCommitment = BigInt("0x" + createHash('sha256').update(randomnessInput).digest('hex'));

        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const getTicketsResult = await tonTut.send(
        //         player1.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetRaffleTicketsMessage",
        //             raffleId: BigInt(0),
        //             account: player1.address,
        //             amount: BigInt(0),
        //             nonce: BigInt(0),
        //             randomness: BigInt(100)    
        //         }
        //     );

        //     expect(getTicketsResult.transactions).toHaveTransaction({
        //         from: player1.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const totalSum = await tonTut.getGetTotalSum(BigInt(0));
        //     expect(totalSum).toBe(BigInt(0));

        //     const randomnessOpening = randomnessInput;

        //     const winnerResult = await tonTut.getGetWinner(BigInt(0));
        //     expect(winnerResult).toBeNull();

        //     const getWinnerResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetWinnerMessage",
        //             raffleId: BigInt(0),
        //             randomnessOpening:randomnessOpening   
        //         }
        //     );

        //     expect(getWinnerResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const winner = await tonTut.getGetWinner(BigInt(0));
        //     expect(winner).toBeNull();
        // });
        // it('should fail with invalid randomnes opening', async () => {
        //     const randomnessInput = "test";
        //     const randomnessCommitment = BigInt("0x" + createHash('sha256').update(randomnessInput).digest('hex'));

        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const randomnessOpening = 'wrong input';

        //     const getWinnerResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetWinnerMessage",
        //             raffleId: BigInt(0),
        //             randomnessOpening:randomnessOpening   
        //         }
        //     );

        //     expect(getWinnerResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: false,
        //     });

        //     const winner = await tonTut.getGetWinner(BigInt(0));
        //     expect(winner).toBeNull();
        // });
        // it('should not get tickets if commitment already opened', async () => {
        //     const randomnessInput = "test";
        //     const randomnessCommitment = BigInt("0x" + createHash('sha256').update(randomnessInput).digest('hex'));

        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const getTicketsResult = await tonTut.send(
        //         player1.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetRaffleTicketsMessage",
        //             raffleId: BigInt(0),
        //             account: player1.address,
        //             amount: BigInt(1),
        //             nonce: BigInt(0),
        //             randomness: BigInt(100)    
        //         }
        //     );

        //     expect(getTicketsResult.transactions).toHaveTransaction({
        //         from: player1.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const totalSum = await tonTut.getGetTotalSum(BigInt(0));
        //     expect(totalSum).toBe(BigInt(1));

        //     const getTicketsResult2 = await tonTut.send(
        //         player1.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetRaffleTicketsMessage",
        //             raffleId: BigInt(0),
        //             account: player2.address,
        //             amount: BigInt(14),
        //             nonce: BigInt(0),
        //             randomness: BigInt(100)    
        //         }
        //     );

        //     expect(getTicketsResult2.transactions).toHaveTransaction({
        //         from: player1.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const totalSum2 = await tonTut.getGetTotalSum(BigInt(0));
        //     expect(totalSum2).toBe(BigInt(15));
        //     const randomnessOpening = randomnessInput;

        //     const winnerResult = await tonTut.getGetWinner(BigInt(0));
        //     expect(winnerResult).toBeNull();

        //     const getWinnerResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetWinnerMessage",
        //             raffleId: BigInt(0),
        //             randomnessOpening:randomnessOpening   
        //         }
        //     );

        //     expect(getWinnerResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const winner = await tonTut.getGetWinner(BigInt(0));
        //     expect(winner).not.toBeNull();

        //     const getTicketsResultAfterCommitmentOpened = await tonTut.send(
        //         player1.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetRaffleTicketsMessage",
        //             raffleId: BigInt(0),
        //             account: player1.address,
        //             amount: BigInt(1),
        //             nonce: BigInt(0),
        //             randomness: BigInt(100)    
        //         }
        //     );

        //     expect(getTicketsResultAfterCommitmentOpened.transactions).toHaveTransaction({
        //         from: player1.address,
        //         to: tonTut.address,
        //         success: false,
        //     });
        // });
        // it('should not get winner with zero totalSum', async () => {
        //     const randomnessInput = "test";
        //     const randomnessCommitment = BigInt("0x" + createHash('sha256').update(randomnessInput).digest('hex'));
        //     const createRaffleResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.05'),
        //         },
        //         {
        //             $$type: "CreateNewRaffleMessage",
        //             randomnessCommitment: randomnessCommitment,
        //             key: BigInt(0)
        //         }
        //     );

        //     expect(createRaffleResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const randomnessOpening = randomnessInput;


        //     const getWinnerResult = await tonTut.send(
        //         deployer.getSender(),
        //         {
        //             value: toNano('0.15'),
        //         },
        //         {
        //             $$type: "GetWinnerMessage",
        //             raffleId: BigInt(0),
        //             randomnessOpening:randomnessOpening   
        //         }
        //     );

        //     expect(getWinnerResult.transactions).toHaveTransaction({
        //         from: deployer.address,
        //         to: tonTut.address,
        //         success: true,
        //     });

        //     const winner = await tonTut.getGetWinner(BigInt(0));
        //     expect(winner).toBeNull();
        // });
        // it('should fail creating new game if signarute is not valid', async () => {});
        // it('fails increasing player amount if signature is not valid', async () => {});
        // it('should return correct winner', async () => {});
        // it('should return correct winner with boundary values', async () => {});
        // it('invalid randomness', async () => {});
        // it('replay attack same game', async () => {});
        // it('replay attack different game', async () => {});
        // it('should correctly pause and unpause', async () => {});
        // it('should correctly return raffle details', async () => {});
        // //////
        // it('bound or default with equal min max', async () => {});
        // it('get winner with zero total sum', async () => {});
        // it('raffle tickets commitment already opened', async () => {});
        // it('get raffle tickets invalid raffleId', async () => {});
        // it('new raffle when game not concluded', async () => {});
        // it('multiple participation', async () => {});
        // it('benchmark many users', async () => {});
    });
});
