import Time "mo:base/Time";
import Result "mo:base/Result";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

module {
    public type RecordIndex = Nat;

    public module RecordIndex = {
        public func equal(x : RecordIndex, y : RecordIndex) : Bool {
            x == y
        };

        public func hash(x : RecordIndex) : Hash.Hash {
            Text.hash(Nat.toText(x))
        };
    };
    /// Update call operations
    public type Operation = {
        #mint;
        #burn;
        #transfer;
        #batchTransfer;
        #approve;
    };
    /// Update call operation record fields
    public type OpRecord = {
        caller: Principal;
        op: Operation;
        index: Nat;
        from: ?Principal;
        to: ?Principal;
        amount: Nat;
        fee: Nat;
        timestamp: Time.Time;
    };

    public type WithDrawRecord = {
        caller: Principal;
        accountId: Text;
        op: Operation;
        index: Nat;
        amount: Nat;
        fee: Nat;
        timestamp: Time.Time;
    };

    public type StorageActor = actor {
        addRecord : shared (record: OpRecord) -> async Bool;
        addRecords : shared (records: [OpRecord]) -> async Bool;
    };

    public type BlockHeight = Nat64;
    public type TransactionIndex = Nat;
    public type SubAccount = [Nat8];
    public type ICPTransactionRecord = {
        from_subaccount: ?SubAccount;
        blockHeight: BlockHeight;
    };

    public type MintInfo = {
        principalId: Principal;
        accountId: Text;
        amount: Nat;
    };

    public type Balance = Nat;
    public type TransferResponse = Result.Result<TransactionIndex, {
        #Unauthorized;
        #LessThanFee;
        #InsufficientBalance;
        #AllowedInsufficientBalance;
        #Other;
    }>;

    public type MintResponse = Result.Result<TransactionIndex, {
        #BlockError: Text;
        #NotTransferType;
        #NotRecharge;
        #AlreadyMint;
    }>;

    public type BurnResponse = Result.Result<TransactionIndex, {
        #InsufficientBalance;
        #LessThanMinBurnAmount;
        #Other;
    }>;

    public module BlockHeight = {
        public func equal(x : BlockHeight, y : BlockHeight) : Bool {
            x == y
        };
        public func hash(x : BlockHeight) : Hash.Hash {
            Text.hash(Nat64.toText(x))
        };
    };
};    
