import { Blockchain, SandboxContract, TreasuryContract } from "@ton/sandbox";
import { toNano } from "@ton/core";
import { LingoRaffle } from "../wrappers/TonTut";
import "@ton/test-utils";
import { createHash } from "node:crypto";

describe("TonTut", () => {
  let blockchain: Blockchain;
  let deployer: SandboxContract<TreasuryContract>;
  let tonTut: SandboxContract<LingoRaffle>;
  let player1: SandboxContract<TreasuryContract>;
  let player2: SandboxContract<TreasuryContract>;
  let signer: SandboxContract<TreasuryContract>;

  beforeEach(async () => {
    blockchain = await Blockchain.create();

    deployer = await blockchain.treasury("deployer");
    player1 = await blockchain.treasury("player1");
    player2 = await blockchain.treasury("player2");
    signer = await blockchain.treasury("signer");

    tonTut = blockchain.openContract(
      await LingoRaffle.fromInit(1n, deployer.address, BigInt(2))
    );

    const deployResult = await tonTut.send(
      deployer.getSender(),
      {
        value: toNano("0.05"),
      },
      {
        $$type: "Deploy",
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
  describe("Basic functionality", () => {
    it("should deploy", async () => {
      // the check is done inside beforeEach
      // blockchain and LingoRaffle are ready to use
    });
    it("should change signer", async () => {
      const newSigner = await blockchain.treasury("newSigner");

      const signerBefore = await tonTut.getOwner();

      expect(signerBefore.toString()).toBe(deployer.address.toString());

      const changeOwnerResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
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
    it("should revers if signer incorrect", async () => {
      const newSigner = await blockchain.treasury("newSigner");

      const signerBefore = await tonTut.getOwner();

      expect(signerBefore.toString()).toBe(deployer.address.toString());

      const changeOwnerResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
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

      const randomnessInput = "test";
      const randomnessCommitment = BigInt(
        "0x" + createHash("sha256").update(randomnessInput).digest("hex")
      );

      const createRaffleResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
        }
      );

      expect(createRaffleResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: false,
      });

      const createRaffleResult2 = await tonTut.send(
        newSigner.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
        }
      );

      expect(createRaffleResult2.transactions).toHaveTransaction({
        from: newSigner.address,
        to: tonTut.address,
        success: true,
      });
    });
  });

  describe("Raffle functionality", () => {
    it("correctly creates new game", async () => {
      const randomnessInput = "test";
      const randomnessCommitment = BigInt(
        "0x" + createHash("sha256").update(randomnessInput).digest("hex")
      );

      const createRaffleResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
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
    it("should change randomness after adding player tickets", async () => {
      const randomnessInput = "test1";
      const randomnessCommitment = BigInt(
        "0x" + createHash("sha256").update(randomnessInput).digest("hex")
      );

      const createRaffleResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
        }
      );

      expect(createRaffleResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const currentRandomness = await tonTut.getGetRaffleCurrentRandomness(0n);

      const getTicketsResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.15"),
        },
        {
          $$type: "GetRaffleTicketsMessage",
          raffleId: BigInt(0),
          account: player1.address,
          amount: BigInt(1),
          randomness: BigInt(100),
        }
      );

      expect(getTicketsResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const newRandomness = await tonTut.getGetRaffleCurrentRandomness(0n);

      expect(newRandomness).not.toBe(currentRandomness);
    });
    it("should correctly get raffle randomness commitment", async () => {
      const randomnessInput = "test";
      const randomnessCommitment = BigInt(
        "0x" + createHash("sha256").update(randomnessInput).digest("hex")
      );

      const createRaffleResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
        }
      );

      expect(createRaffleResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const getRaffleRandomnessCommitment =
        await tonTut.getGetRaffleRandomnessCommitment(BigInt(0));
      expect(getRaffleRandomnessCommitment).toBe(randomnessCommitment);
    });
    it("should correctly get raffle current randomness", async () => {
      const randomnessInput = "test";
      const randomnessCommitment = BigInt(
        "0x" + createHash("sha256").update(randomnessInput).digest("hex")
      );

      const createRaffleResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
        }
      );

      expect(createRaffleResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const raffleCurrentRandomness =
        await tonTut.getGetRaffleCurrentRandomness(BigInt(0));
      expect(raffleCurrentRandomness).toBe(randomnessCommitment);
    });
    it("should correctly get raffle commitment opened after creating new game", async () => {
      const randomnessInput = "test";
      const randomnessCommitment = BigInt(
        "0x" + createHash("sha256").update(randomnessInput).digest("hex")
      );

      const createRaffleResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
        }
      );

      expect(createRaffleResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const raffleCommitmentOpened = await tonTut.getGetRaffleCommitmentOpened(
        BigInt(0)
      );
      expect(raffleCommitmentOpened).toBe(false);
    });

    it("should get winner", async () => {
      const randomnessInput = "test";
      const randomnessCommitment = BigInt(
        "0x" + createHash("sha256").update(randomnessInput).digest("hex")
      );

      const createRaffleResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
        }
      );

      expect(createRaffleResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const getTicketsResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.15"),
        },
        {
          $$type: "GetRaffleTicketsMessage",
          raffleId: BigInt(0),
          account: player1.address,
          amount: BigInt(1),
          randomness: BigInt(100),
        }
      );

      expect(getTicketsResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const getTicketsResult2 = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.15"),
        },
        {
          $$type: "GetRaffleTicketsMessage",
          raffleId: BigInt(0),
          account: player2.address,
          amount: BigInt(14),
          randomness: BigInt(100),
        }
      );

      expect(getTicketsResult2.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const randomnessOpening = randomnessInput;

      const winnerResult = await tonTut.getGetWinner(BigInt(0));
      expect(winnerResult).toBeNull();

      const getWinnerResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.15"),
        },
        {
          $$type: "SetWinnerMessage",
          raffleId: BigInt(0),
          randomnessOpening: randomnessOpening,
          winner: player2.address,
        }
      );

      expect(getWinnerResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const winner = await tonTut.getGetWinner(BigInt(0));

      expect(winner).not.toBeNull();
      expect(winner?.toString()).toBe(player2.address.toString());
    });

    it("should fail with invalid randomnes opening", async () => {
      const randomnessInput = "test";
      const randomnessCommitment = BigInt(
        "0x" + createHash("sha256").update(randomnessInput).digest("hex")
      );

      const createRaffleResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
        }
      );

      expect(createRaffleResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const randomnessOpening = "wrong input";

      const getWinnerResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.15"),
        },
        {
          $$type: "SetWinnerMessage",
          raffleId: BigInt(0),
          randomnessOpening: randomnessOpening,
          winner: player1.address,
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
    it("should not get tickets if commitment already opened", async () => {
      const randomnessInput = "test";
      const randomnessCommitment = BigInt(
        "0x" + createHash("sha256").update(randomnessInput).digest("hex")
      );

      const createRaffleResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.05"),
        },
        {
          $$type: "CreateNewRaffleMessage",
          randomnessCommitment: randomnessCommitment,
          key: BigInt(0),
        }
      );

      expect(createRaffleResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const getTicketsResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.15"),
        },
        {
          $$type: "GetRaffleTicketsMessage",
          raffleId: BigInt(0),
          account: player1.address,
          amount: BigInt(1),
          randomness: BigInt(100),
        }
      );

      expect(getTicketsResult.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const getTicketsResult2 = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.15"),
        },
        {
          $$type: "GetRaffleTicketsMessage",
          raffleId: BigInt(0),
          account: player2.address,
          amount: BigInt(14),
          randomness: BigInt(100),
        }
      );

      expect(getTicketsResult2.transactions).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: true,
      });

      const randomnessOpening = randomnessInput;

      const winnerResult = await tonTut.getGetWinner(BigInt(0));
      expect(winnerResult).toBeNull();

      const getWinnerResult = await tonTut.send(
        deployer.getSender(),
        {
          value: toNano("0.15"),
        },
        {
          $$type: "SetWinnerMessage",
          raffleId: BigInt(0),
          randomnessOpening: randomnessOpening,
          winner: player1.address,
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
        deployer.getSender(),
        {
          value: toNano("0.15"),
        },
        {
          $$type: "GetRaffleTicketsMessage",
          raffleId: BigInt(0),
          account: player1.address,
          amount: BigInt(1),
          randomness: BigInt(100),
        }
      );

      expect(
        getTicketsResultAfterCommitmentOpened.transactions
      ).toHaveTransaction({
        from: deployer.address,
        to: tonTut.address,
        success: false,
      });
    });
  });
});
