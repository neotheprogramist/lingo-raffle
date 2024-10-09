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
    account: Address;
    amount: Int as uint256;
    nonce: Int as uint256;
    signature: Slice;
    randomness: Int as uint256;
}
struct RaffleTicketsData {
    raffleId: Int as uint256;
    account: Address;
    amount: Int as uint256;
    nonce: Int as uint256;
    randomness: Int as uint256;
}
message PlayerAmountIncreasedEvent {
    raffleId: Int as uint256;
    player: Address;
    amount: Int as uint256;
    nonce: Int as uint256;
}
message GetWinnerMessage {
    raffleId: Int as uint256;
    randomnessOpening: String;
}
message ChangeSignerMessage {
   newSigner: Address;
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
    playerNonces: map<Address, Int as uint256>;
    winner: Address?;
}
struct Node {
    value: Int as uint256;
    left: Address?;
    leftSum: Int as uint256;
    right: Address?;
    rightSum: Int as uint256;
}
struct Tree {
    root: Address;
    totalSum: Int as uint256;
    nodes: map<Address, Node>;
}
// struct Signature {
//     v: Int as uint8;
//     r: Slice as bytes32;
//     s: Slice as bytes32;
// }
// struct SignatureParts {
//     signature: Signature;
//     hash: Int;
// }

// TODO: implement replys
contract LingoRaffle with Deployable, Ownable, Resumable {
    owner: Address;
    signer: Address;
    stopped: Bool;
    rafflesBuffer: map<Int as uint256, Raffle>;
    treesBuffer: map<Int as uint256, Tree>;
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
        self.rafflesBuffer.set(self.currentIndex,
            Raffle{
                randomnessCommitment: msg.randomnessCommitment,
                currentRandomness: msg.randomnessCommitment,
                commitmentOpened: false,
                playerNonces: emptyMap()
            }
        );
        self.treesBuffer.set(self.currentIndex,
            Tree{root: newAddress(0, 0x7fFFfFfFFFfFFFFfFffFfFfFfffFFfFfFffFFFFf), totalSum: 0, nodes: emptyMap()}
        );
        self.increaseIndex();
        emit(RaffleCreatedEvent{raffleId: self.currentIndex, randomnessCommitment: msg.randomnessCommitment}.toCell());
    }

    receive(msg: GetRaffleTicketsMessage){
        self.requireNotStopped(); // cant work if a contract is stopped
        require(msg.raffleId >= 0 && msg.raffleId <= self.maxIndex, "Raffle with this key does not exist");
        let data: RaffleTicketsData = RaffleTicketsData{
            raffleId: msg.raffleId,
            account: msg.account,
            amount: msg.amount,
            nonce: msg.nonce,
            randomness: msg.randomness
        };
        let hash: Int = beginCell().storeRef(data.toCell()).endCell().hash();
        let check: Bool = checkSignature(hash, msg.signature, self.signerPublicKey);
        dump(check);
        // require(checkSignature())
        let raffle = self.rafflesBuffer.get(msg.raffleId)!!;
        require(!raffle.commitmentOpened, "Raffle commitment already opened");
        
        let accountNonce: Int? = raffle.playerNonces.get(msg.account);
        if (accountNonce == null) {
            accountNonce = 0;
        }
        accountNonce = accountNonce!! + 1;
        
        let updatedRaffle = Raffle{
            randomnessCommitment: raffle.randomnessCommitment,
            currentRandomness: raffle.currentRandomness,
            commitmentOpened: raffle.commitmentOpened,
            playerNonces: raffle.playerNonces
        };
        updatedRaffle.playerNonces.set(msg.account, accountNonce);
        
        self.insert(msg.raffleId, msg.account, msg.amount);
       
        let serializeData = beginString().concat(updatedRaffle.currentRandomness.toString()).concat(msg.randomness.toString());
        updatedRaffle.currentRandomness = sha256(serializeData.toString());
        
        self.rafflesBuffer.set(msg.raffleId, updatedRaffle);
        
        emit(PlayerAmountIncreasedEvent{raffleId: msg.raffleId, player: msg.account, amount: msg.amount, nonce: accountNonce!!}.toCell());
    }

    receive(msg: GetWinnerMessage){
        self.requireNotStopped();
        self.requireOwner();
     
        let raffle = self.rafflesBuffer.get(msg.raffleId)!!;
    
        require(sha256(msg.randomnessOpening) == raffle.randomnessCommitment, "Invalid randomness openin");
       
        require(!raffle.commitmentOpened,"Raffle commitment already opened");
      
        raffle.commitmentOpened = true;
        self.rafflesBuffer.set(msg.raffleId, raffle);
        let serializeData = beginString().concat(raffle.currentRandomness.toString()).concat(msg.randomnessOpening);
        let currentRandomness = sha256(serializeData.toString());
        let max: Int = self.getTotalSum(msg.raffleId);
        let boundedRandomness: Int = self.boundOrDefault(currentRandomness, 0, max);
        let winner: Address? = self.getByPointOnInterval(msg.raffleId, boundedRandomness);
        raffle.winner = winner;
   
        self.rafflesBuffer.set(msg.raffleId, raffle);
        emit(WinnerDeclaredEvent{raffleId: msg.raffleId, winner: winner}.toCell());  
    }
    get fun getRaffle(key: Int): Raffle? {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let raffle = self.rafflesBuffer.get(key);
        return raffle;
    }

    get fun getRaffleRandomnessCommitment(key: Int): Int {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let raffle = self.rafflesBuffer.get(key);
        return raffle!!.randomnessCommitment;
    }

    get fun getRaffleCurrentRandomness(key: Int): Int {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let raffle = self.rafflesBuffer.get(key);
        return raffle!!.currentRandomness;
    }

    get fun getRaffleCommitmentOpened(key: Int): Bool {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let raffle = self.rafflesBuffer.get(key)!!;
        return raffle.commitmentOpened;
    }

    get fun getTotalSum(key: Int): Int {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let tree = self.treesBuffer.get(key);
        return tree!!.totalSum;
    }

    get fun getPlayerAmount(key: Int, account: Address): Int {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        
        let raffle = self.rafflesBuffer.get(key);
        return raffle!!.playerNonces.get(account)!!;
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
        return raffle!!.winner;
    }
    // trees functions
    fun insert(key: Int,account: Address, amount: Int) {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let currentTree = self.treesBuffer.get(key)!!;
        let parent: Address = newAddress(0,0);
        let current: Address? = currentTree.root;
        let shouldIterate: Bool = true;
        while(current != null && shouldIterate) {
            parent = current!!;
            
            if(parent == account) {
                shouldIterate = false;
            } else if (parent.asSlice().hash() < account.asSlice().hash()) {
                let node: Node? = currentTree.nodes.get(parent);
                let newNode: Node = Node{
                                    value: 0,
                                    left: null,
                                    leftSum: 0,
                                    right: null,
                                    rightSum: 0
                                };
                if(node == null){
                   newNode.leftSum += amount;
                }else{
                    newNode.leftSum = node!!.leftSum +amount;
                }

                currentTree.nodes.set(parent, node);
                current = newNode.left;
                if(current == null){
                    newNode.left = account;
                    currentTree.nodes.set(parent, newNode);
                    current = account;
                }
            } else {
                let node: Node? = currentTree.nodes.get(parent);
                let newNode: Node = Node{
                    value: 0,
                    left: null,
                    leftSum: 0,
                    right: null,
                    rightSum: 0
                };
                if(node == null){
                   newNode.rightSum += amount;
                }else{
                    newNode.rightSum = node!!.rightSum +amount;
                }

                currentTree.nodes.set(parent, node);
           
                current = newNode.right;
                if(current == null){
                    newNode.right = account;
                    
                    currentTree.nodes.set(parent, newNode);
                    current = account;
                }
            }

        }

        if (current == null) {
            currentTree.nodes.set(account, Node{
                value: amount,
                left: null,
                leftSum: 0,
                right: null,
                rightSum: 0
            });
        } else {
            let node: Node? = currentTree.nodes.get(current!!);
            let newNode: Node = Node{
                value: 0,
                left: null,
                leftSum: 0,
                right: null,
                rightSum: 0
            };
            if(node == null){
                newNode.value = amount;
            } else {
                newNode.value += amount;
            }
            currentTree.nodes.set(current!!, newNode);
        }
        let tree: Tree = currentTree;
        tree.totalSum += amount;

        self.treesBuffer.set(key, tree);
    }

    get fun getTreeAccountValue(key: Int,account: Address): Int {
         require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let currentTree = self.treesBuffer.get(key);
        let current: Address = currentTree!!.root;

        let uintCurrent = current.toString().asSlice().loadUint(256);
        let uintAccount = account.toString().asSlice().loadUint(256);
        while (current != newAddress(0,0)) {
            if (current == account) {
                let node: Node = currentTree!!.nodes.get(current)!!;
                return node.value;
            } else if (uintCurrent > uintAccount) {
                current = currentTree!!.nodes.get(current)!!.left!!;
            } else {
                current = currentTree!!.nodes.get(current)!!.right!!;
            }
        }

        return 0; 
    }

    get fun getByPointOnInterval(key: Int, value: Int): Address? {
        require(key >= 0 && key <= self.maxIndex, "Raffle with this key does not exist");
        let currentTree = self.treesBuffer.get(key)!!;
        let current: Address? = currentTree.root;
        if(currentTree.totalSum == 0){
            return null;
        }

        while (current != null) {
            let node: Node? = currentTree.nodes.get(current!!);
            if(value < node!!.leftSum){
                current = node!!.left;
            } else if(value < node!!.leftSum + node!!.value){
                return current;
            } else {
                value -= node!!.leftSum + node!!.value;
                current = node!!.right;
            }
        }

        return null; 
    }

}