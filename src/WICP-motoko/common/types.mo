import Time "mo:base/Time";
import Result "mo:base/Result";
import Hash "mo:base/Hash";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

module {
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

    public type StorageActor = actor {
        addRecord : (caller: Principal, op: Operation, from: ?Principal, to: ?Principal, amount: Nat,
            fee: Nat, timestamp: Time.Time) -> async Nat;
    };

    public type BlockHeight = Nat64;
    public type TransactionIndex = Nat;
    public type SubAccount = [Nat8];
    public type ICPTransactionRecord = {
        from_subaccount: ?SubAccount;
        blockHeight: BlockHeight;
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
