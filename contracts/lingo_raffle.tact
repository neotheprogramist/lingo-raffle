import "@stdlib/deploy";
import "@stdlib/ownable";
import "@stdlib/stoppable";
message CrackTheEggMessage {
    data: Int as uint256;
}
message CrackTheEggEvent {
    sender: Address;
    timestamp: Int as uint64;
    data: Int as uint256;
}
message RaffleCreatedEvent {
    raffleId: Int as uint256;
    randomnessCommitment: Int as uint256;
}
message GetRaffleTicketsMessage {
    raffleId: Int as uint256;
    randomness: Int as uint256;
    account: Address;
    amount: Int;
}
struct RaffleTicketsData {
    raffleId: Int as uint256;
    randomness: Int as uint256;
}
message SetWinnerMessage {
    raffleId: Int as uint256;
    randomnessOpening: String;
    winner: Address;
}
message ChangeSignerMessage {
   newSigner: Address;
}
message PlayerAmountIncreasedEvent{
    raffleId: Int as uint256;
    player: Address;
    amount: Int;
}
message WinnerDeclaredEvent {
    raffleId: Int as uint256;
    winner: Address?;
}
message CreateNewRaffleMessage {
    key: Int as uint256;
    randomnessCommitment: Int as uint256;
}
// structs
struct Raffle {
    randomnessCommitment: Int as uint256;
    currentRandomness: Int as uint256;
    commitmentOpened: Bool;
    winner: Address?;
}


// TODO: implement replys
contract LingoRaffle with Deployable, Ownable, Resumable {
    owner: Address;
    signer: Address;
    stopped: Bool;
    rafflesBuffer: map<Int as uint256, Raffle>;
    currentIndex: Int as int8;
    maxIndex: Int as int8;
    signerPublicKey: Int;
    init(maxIndex: Int, signer: Address, signerPublicKey: Int){
        self.stopped = false;
        self.currentIndex = 0;
        self.maxIndex = maxIndex;
        self.owner = sender();
        self.signer = signer;
        self.signerPublicKey = signerPublicKey;
    }

    receive(msg: CrackTheEggMessage){
        emit(CrackTheEggEvent{sender: sender(), timestamp: now(), data: msg.data}.toCell());
    }

    get fun getOwner(): Address {
        return self.owner;
    }
    get fun getSigner(): Address {
        return self.signer;
    }

    receive(msg: ChangeSignerMessage){
        self.requireOwner();
        self.signer = msg.newSigner;
    }

    fun increaseIndex() {
        self.currentIndex += 1;
        if (self.currentIndex > self.maxIndex) {
            self.currentIndex = 0;
        }
    }

    receive(msg: CreateNewRaffleMessage){
        self.requireNotStopped(); // cant work if a contract is stopped
        require(self.signer == sender(), "wrong signer");
        self.rafflesBuffer.set(self.currentIndex,
            Raffle{
                randomnessCommitment: msg.randomnessCommitment,
                currentRandomness: msg.randomnessCommitment,
                commitmentOpened: false,
                winner: null
            }
        );
        self.increaseIndex();
        emit(RaffleCreatedEvent{raffleId: self.currentIndex, randomnessCommitment: msg.randomnessCommitment}.toCell());
    }

    receive(msg: GetRaffleTicketsMessage){
        self.requireNotStopped(); // cant work if a contract is stopped
        require(self.signer == sender(), "wrong signer");
        require(msg.raffleId >= 0 && msg.raffleId <= self.maxIndex, "Raffle with this key does not exist");

        let raffle = self.rafflesBuffer.get(msg.raffleId)!!;
        require(!raffle.commitmentOpened, "Raffle commitment already opened");

        let updatedRaffle = Raffle{
            randomnessCommitment: raffle.randomnessCommitment,
            currentRandomness: raffle.currentRandomness,
            commitmentOpened: raffle.commitmentOpened,
        };

        let serializeData = beginString().concat(updatedRaffle.currentRandomness.toString()).concat(msg.randomness.toString());
        updatedRaffle.currentRandomness = sha256(serializeData.toString());

        self.rafflesBuffer.set(msg.raffleId, updatedRaffle);

        emit(PlayerAmountIncreasedEvent{raffleId: msg.raffleId, player: msg.account, amount: msg.amount}.toCell());
    }

    receive(msg: SetWinnerMessage){
        self.requireNotStopped();
        self.requireOwner();

        let raffle = self.rafflesBuffer.get(msg.raffleId)!!;

        require(sha256(msg.randomnessOpening) == raffle.randomnessCommitment, "Invalid randomness openin");

        require(!raffle.commitmentOpened,"Raffle commitment already opened");
        raffle.commitmentOpened = true;
        self.rafflesBuffer.set(msg.raffleId, raffle);
        let serializeData = beginString().concat(raffle.currentRandomness.toString()).concat(msg.randomnessOpening);
        let currentRandomness = sha256(serializeData.toString());

        raffle.winner = msg.winner;

        self.rafflesBuffer.set(msg.raffleId, raffle);
        emit(WinnerDeclaredEvent{raffleId: msg.raffleId, winner: msg.winner}.toCell());

    }
    get fun getRaffle(key: Int): Raffle? {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let raffle = self.rafflesBuffer.get(key);
        return raffle;
    }

    get fun getRaffleRandomnessCommitment(key: Int): Int? {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let raffle = self.rafflesBuffer.get(key);
        if(raffle != null){
        return raffle!!.randomnessCommitment;
        } else {
            return null;
        }
    }

    get fun getRaffleCurrentRandomness(key: Int): Int? {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let raffle = self.rafflesBuffer.get(key);
        if(raffle != null){
            return raffle!!.currentRandomness;
        } else {
            return null;
        }
    }

    get fun getRaffleCommitmentOpened(key: Int): Bool? {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let raffle = self.rafflesBuffer.get(key);
        if(raffle != null){
        return raffle!!.commitmentOpened;
        }else {
            return null;
        }
    }
    fun boundOrDefault(value: Int, min: Int, max: Int): Int {
            let uint256Max: Int = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
            if(max > min){
                let range: Int = max - min;
                while(range * (uint256Max / range) <= value){
                    value = sha256(value.toString());
                }
                return min + (value % range);
            }else{
                return 0;
            }
    }

    get fun getWinner(key: Int): Address? {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let raffle = self.rafflesBuffer.get(key);
        if(raffle != null){
        return raffle!!.winner;
        } else {
            return null;
        }
    }
}