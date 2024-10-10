import { Blockchain,  SandboxContract, TreasuryContract } from '@ton/sandbox';
import {  Slice, toNano, Cell, beginCell, Address } from '@ton/core';
import { LingoRaffle } from '../wrappers/TonTut';
import '@ton/test-utils';
import { createHash } from 'node:crypto';
const { keyPairFromSeed, sign } = require('ton-crypto');
import nacl from 'tweetnacl';


const keyPair = nacl.sign.keyPair();
const publicKey = Buffer.from(keyPair.publicKey);
const privateKey = Buffer.from(keyPair.secretKey);


function serializeData(
    raffleData:any
) {
    const tonAddress = Address.parse(raffleData.account.address.toString());

    const randomnessCell = beginCell()
    .storeUint(raffleData.randomness, 256) 
    .endCell();

    const cell = beginCell()
        .storeUint(raffleData.raffleId, 256)
        .storeAddress(tonAddress)
        .storeUint(raffleData.amount, 256) 
        .storeUint(raffleData.nonce, 64)
        .storeRef(randomnessCell)
        // .storeUint(raffleData.randomness, 256)
        .endCell();
        
    // console.log('cell: ',cell);
    return cell;
}

function signRaffleData(raffleData: any, privateKey: Buffer) {
    const cell = serializeData(raffleData);
    const dataHash = cell.hash(); 
    // console.log('hashData: ',BigInt('0x'+dataHash.toString('hex')));
    const signature = nacl.sign.detached(dataHash, privateKey); 

    return Buffer.from(signature);
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
      
        tonTut = blockchain.openContract(await LingoRaffle.fromInit(1n, deployer.address, BigInt('0x'+Buffer.from(publicKey).toString('hex'))));

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
    it('should check signature', async () => {  
            const signerBefore = await tonTut.getOwner();
            
            expect(signerBefore.toString()).toBe(deployer.address.toString());

            const cell = beginCell()
            .storeUint(BigInt(200), 256)
            .endCell();

            const message = JSON.stringify(cell);
            const messageBytes = new TextEncoder().encode(message);
            const dataHash = cell.hash(); 
            console.log('hashData: ',BigInt('0x'+dataHash.toString('hex')));
            const signature = nacl.sign.detached(dataHash, privateKey); 

            const signatureBuffer = Buffer.from(signature);
            const signatureCell: Cell = beginCell().storeBuffer(signatureBuffer).endCell();

            const signatureSlice: Slice = signatureCell.asSlice();
            // console.log('signatureSlice: ',signatureSlice);

            const changeOwnerResult = await tonTut.send(
                deployer.getSender(),
                {
                    value: toNano('0.05'),
                },
                {
                    $$type: "SigCheck",
                    signature: signatureSlice,
                    data: cell
                }
            );
    
            expect(changeOwnerResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: tonTut.address,
                success: true,
            });
    })
    describe('Basic functionality', ()=>{
        it('should deploy', async () => {
            // the check is done inside beforeEach
            // blockchain and tonTut are ready to use
        });
        it('should change signer', async () => {
            const newSigner = await blockchain.treasury('newSigner');
    
            const signerBefore = await tonTut.getOwner();
            
            expect(signerBefore.toString()).toBe(deployer.address.toString());
    
            const changeOwnerResult = await tonTut.send(
                deployer.getSender(),
                {
                    value: toNano('0.05'),
                },
                {
                    $$type: "ChangeSignerMessage",
                    newSigner: newSigner.address,
                }
            );
    
            expect(changeOwnerResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: tonTut.address,
                success: true,
            });
    
            const signerAfter = await tonTut.getGetSigner();
    
            expect(signerAfter).toEqualAddress(newSigner.address);
        });
    })
   
    describe('Raffle functionality', () => {
        it('correctly creates new game', async () => {
            const randomnessInput = "test";
            const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
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

            const getRaffle = await tonTut.getGetRaffle(BigInt(0));
            expect(getRaffle!.randomnessCommitment).toBe(randomnessCommitment);
        });
        it('should correctly apply tickets to players account', async () => {
            const randomnessInput = "test1";
            const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
            
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
                    nonce: BigInt(0),
                    randomness: BigInt(100)    
                }
            );

            expect(getTicketsResult.transactions).toHaveTransaction({
                from: player1.address,
                to: tonTut.address,
                success: true,
            });

            const playerAmount = await tonTut.getGetPlayerAmount(BigInt(0), player1.address);
            expect(playerAmount).toBe(BigInt(1));
        });
        it('should correctly get raffle randomness commitment', async () => {
             const randomnessInput = "test";
            const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
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

            const getRaffleRandomnessCommitment = await tonTut.getGetRaffleRandomnessCommitment(BigInt(0));
            expect(getRaffleRandomnessCommitment).toBe(randomnessCommitment);
        });
        it('should correctly get raffle current randomness', async () => {
             const randomnessInput = "test";
            const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
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

            const raffleCurrentRandomness = await tonTut.getGetRaffleCurrentRandomness(BigInt(0));
            expect(raffleCurrentRandomness).toBe(randomnessCommitment);
        });
        it('should correctly get raffle commitment opened after creating new game', async () => {
             const randomnessInput = "test";
            const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
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

            const raffleCommitmentOpened = await tonTut.getGetRaffleCommitmentOpened(BigInt(0));
            expect(raffleCommitmentOpened).toBe(false);
        });
        it('should correctly get correctly get current raffle total sum', async () => {
             const randomnessInput = "test";
            const randomnessCommitment = BigInt('0x' + createHash('sha256').update(randomnessInput).digest('hex'));
  
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
                    nonce: BigInt(0),
                    randomness: BigInt(100)    
                }
            );

            expect(getTicketsResult.transactions).toHaveTransaction({
                from: player1.address,
                to: tonTut.address,
                success: true,
            });

            const totalSum = await tonTut.getGetTotalSum(BigInt(0));
            expect(totalSum).toBe(BigInt(1));

            const getTicketsResult2 = await tonTut.send(
                player1.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetRaffleTicketsMessage",
                    raffleId: BigInt(0),
                    account: player2.address,
                    amount: BigInt(14),
                    nonce: BigInt(0),
                    randomness: BigInt(100)    
                }
            );

            expect(getTicketsResult2.transactions).toHaveTransaction({
                from: player1.address,
                to: tonTut.address,
                success: true,
            });

            const totalSum2 = await tonTut.getGetTotalSum(BigInt(0));
            expect(totalSum2).toBe(BigInt(15));
        });
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

            // const raffleData = {
            //     raffleId: BigInt(0),
            //     account: player1,
            //     amount: BigInt(1),
            //     nonce: BigInt(0),
            //     randomness: BigInt(100)
            // }

            // const data = await signRaffleData(raffleData, privateKey);

            // const signatureCell: Cell = beginCell().storeBuffer(data).endCell();

            // const signatureSlice: Slice = signatureCell.asSlice();
            // console.log('signatureSlice: ',signatureSlice);
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
                    nonce: BigInt(0),
                    randomness: BigInt(100),
                    // data: serializeData(raffleData),
                    // signature: signatureSlice,
                }
            );

            expect(getTicketsResult.transactions).toHaveTransaction({
                from: player1.address,
                to: tonTut.address,
                success: true,
            });

            const totalSum = await tonTut.getGetTotalSum(BigInt(0));
            expect(totalSum).toBe(BigInt(1));


            // const raffleData2 = {
            //     raffleId: BigInt(0),
            //     account: player1,
            //     amount: BigInt(14),
            //     nonce: BigInt(0),
            //     randomness: BigInt(100)
            // }

            // const data2 = await signRaffleData(raffleData2, privateKey);

            // const signatureCell2: Cell = beginCell().storeBuffer(data2).endCell();

            // const signatureSlice2: Slice = signatureCell2.asSlice();

            const getTicketsResult2 = await tonTut.send(
                player1.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetRaffleTicketsMessage",
                    raffleId: BigInt(0),
                    account: player2.address,
                    // signature: signatureSlice2,
                    amount: BigInt(14),
                    nonce: BigInt(0),
                    randomness: BigInt(100)    
                }
            );

            expect(getTicketsResult2.transactions).toHaveTransaction({
                from: player1.address,
                to: tonTut.address,
                success: true,
            });

            const totalSum2 = await tonTut.getGetTotalSum(BigInt(0));
            expect(totalSum2).toBe(BigInt(15));
            const randomnessOpening = randomnessInput;

            const winnerResult = await tonTut.getGetWinner(BigInt(0));
            expect(winnerResult).toBeNull();

            const getWinnerResult = await tonTut.send(
                deployer.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetWinnerMessage",
                    raffleId: BigInt(0),
                    randomnessOpening:randomnessOpening   
                }
            );

            expect(getWinnerResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: tonTut.address,
                success: true,
            });

            const winner = await tonTut.getGetWinner(BigInt(0));

            expect(winner).not.toBeNull();
        });
        it('should not get winner with one player', async () => {
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

            const getTicketsResult = await tonTut.send(
                player1.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetRaffleTicketsMessage",
                    raffleId: BigInt(0),
                    account: player1.address,
                    amount: BigInt(0),
                    nonce: BigInt(0),
                    randomness: BigInt(100)    
                }
            );

            expect(getTicketsResult.transactions).toHaveTransaction({
                from: player1.address,
                to: tonTut.address,
                success: true,
            });

            const totalSum = await tonTut.getGetTotalSum(BigInt(0));
            expect(totalSum).toBe(BigInt(0));

            const randomnessOpening = randomnessInput;

            const winnerResult = await tonTut.getGetWinner(BigInt(0));
            expect(winnerResult).toBeNull();

            const getWinnerResult = await tonTut.send(
                deployer.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetWinnerMessage",
                    raffleId: BigInt(0),
                    randomnessOpening:randomnessOpening   
                }
            );

            expect(getWinnerResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: tonTut.address,
                success: true,
            });

            const winner = await tonTut.getGetWinner(BigInt(0));
            expect(winner).toBeNull();
        });
        it('should fail with invalid randomnes opening', async () => {
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

            const randomnessOpening = 'wrong input';

            const getWinnerResult = await tonTut.send(
                deployer.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetWinnerMessage",
                    raffleId: BigInt(0),
                    randomnessOpening:randomnessOpening   
                }
            );

            expect(getWinnerResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: tonTut.address,
                success: false,
            });

            const winner = await tonTut.getGetWinner(BigInt(0));
            expect(winner).toBeNull();
        });
        it('should not get tickets if commitment already opened', async () => {
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
                    nonce: BigInt(0),
                    randomness: BigInt(100)    
                }
            );

            expect(getTicketsResult.transactions).toHaveTransaction({
                from: player1.address,
                to: tonTut.address,
                success: true,
            });

            const totalSum = await tonTut.getGetTotalSum(BigInt(0));
            expect(totalSum).toBe(BigInt(1));

            const getTicketsResult2 = await tonTut.send(
                player1.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetRaffleTicketsMessage",
                    raffleId: BigInt(0),
                    account: player2.address,
                    amount: BigInt(14),
                    nonce: BigInt(0),
                    randomness: BigInt(100)    
                }
            );

            expect(getTicketsResult2.transactions).toHaveTransaction({
                from: player1.address,
                to: tonTut.address,
                success: true,
            });

            const totalSum2 = await tonTut.getGetTotalSum(BigInt(0));
            expect(totalSum2).toBe(BigInt(15));
            const randomnessOpening = randomnessInput;

            const winnerResult = await tonTut.getGetWinner(BigInt(0));
            expect(winnerResult).toBeNull();

            const getWinnerResult = await tonTut.send(
                deployer.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetWinnerMessage",
                    raffleId: BigInt(0),
                    randomnessOpening:randomnessOpening   
                }
            );

            expect(getWinnerResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: tonTut.address,
                success: true,
            });

            const winner = await tonTut.getGetWinner(BigInt(0));
            expect(winner).not.toBeNull();

            const getTicketsResultAfterCommitmentOpened = await tonTut.send(
                player1.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetRaffleTicketsMessage",
                    raffleId: BigInt(0),
                    account: player1.address,
                    amount: BigInt(1),
                    nonce: BigInt(0),
                    randomness: BigInt(100)    
                }
            );

            expect(getTicketsResultAfterCommitmentOpened.transactions).toHaveTransaction({
                from: player1.address,
                to: tonTut.address,
                success: false,
            });
        });
        it('should not get winner with zero totalSum', async () => {
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

            const randomnessOpening = randomnessInput;


            const getWinnerResult = await tonTut.send(
                deployer.getSender(),
                {
                    value: toNano('0.15'),
                },
                {
                    $$type: "GetWinnerMessage",
                    raffleId: BigInt(0),
                    randomnessOpening:randomnessOpening   
                }
            );

            expect(getWinnerResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: tonTut.address,
                success: true,
            });

            const winner = await tonTut.getGetWinner(BigInt(0));
            expect(winner).toBeNull();
        });
    });
});
