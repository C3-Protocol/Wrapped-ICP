/**
 * Module     : token.mo
 * Copyright  : 2021 Hellman Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Hellman Team - Leven
 * Stability  : Experimental
 */

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Types "./common/types";
import Storage "./storage";
import LedgerHistory "./common/ledgerHistory";
import AID "./util/AccountIdentifier";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Cycles "mo:base/ExperimentalCycles";

/**
 * Desc: a Token anchor to ICP
 * mint same count WICP when receive ICP from user
 */
shared(msg) actor class Token(_owner: Principal, _feeTo: Principal) {
    type Operation = Types.Operation;
    type OpRecord = Types.OpRecord;
    type WithDrawRecord = Types.WithDrawRecord;
    type BlockHeight = Types.BlockHeight;
    type RecordIndex = Types.RecordIndex;
    type TransactionIndex = Types.TransactionIndex;
    type ICPTransactionRecord = Types.ICPTransactionRecord;
    type TransferResponse = Types.TransferResponse;
    type MintResponse = Types.MintResponse;
    type BurnResponse = Types.BurnResponse;
    type AccountIdentifier = AID.AccountIdentifier;
    type MintInfo = Types.MintInfo;
    type SubAccount = AID.SubAccount;
    type StorageActor = Types.StorageActor;
    type LedgerHistoryActor = LedgerHistory.LedgerHistoryActor;
    type ICPTs = LedgerHistory.ICPTs;
    private stable var cyclesCreateStorage: Nat = 2_000_000_000_000;

    private stable var ledHistoryCanisterActor: LedgerHistoryActor = actor("5xz77-saaaa-aaaah-qalmq-cai");
    private stable var owner_ : Principal = _owner;
    private stable var name_ : Text = "Wrapped ICP";
    private stable var decimals_ : Nat = 8;
    private stable var symbol_ : Text = "WICP";
    private stable var totalSupply_ : Nat = 0;
    private stable var feeTo : Principal = _feeTo;
    private stable var fee : Nat = 0;
    private stable var minBurnAmount : Nat = 10_000_000;
    private stable var receiveICPAccArray : [AccountIdentifier] = [];
    private stable var balanceEntries : [(Principal, Nat)] = [];

    private var balances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
    private var allowances = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Nat>>(1, Principal.equal, Principal.hash);

    private stable var mintBlockHeightEntries : [(BlockHeight, Bool)] = [];
    private var mintBlockHeightMap = HashMap.HashMap<BlockHeight, Bool>(1, Types.BlockHeight.equal, Types.BlockHeight.hash);

    private stable var mintInfoEntries : [(BlockHeight, MintInfo)] = [];
    private var mintInfoMap = HashMap.HashMap<BlockHeight, MintInfo>(1, Types.BlockHeight.equal, Types.BlockHeight.hash);

    private stable var opsIndex : Nat = 0;

    private stable var opsWithDrawEntries : [(RecordIndex, WithDrawRecord)] = [];
    private var opsWithDraw = HashMap.HashMap<RecordIndex, WithDrawRecord>(1, Types.RecordIndex.equal, Types.RecordIndex.hash);

    private stable var storageCanister : ?StorageActor = null;
    private stable var dataUser : Principal = Principal.fromText("umgol-annoi-q7dqt-qbsw6-a2pww-eitzs-6vi5t-efaz6-xquey-5jmut-sqe");

    private func _genRecord(
        caller: Principal, op: Operation, from: ?Principal, to: ?Principal, amount: Nat,
        fee: Nat, timestamp: Time.Time
    ) : OpRecord {
        let index = opsIndex;
        let o : OpRecord = {
            caller = caller;
            op = op;
            index = index;
            from = from;
            to = to;
            amount = amount;
            fee = fee;
            timestamp = timestamp;
        };
        opsIndex += 1;
        return o;
    };

    private func _addWithDrawRecord(
        caller: Principal, accountId: AccountIdentifier, op: Operation, amount: Nat,
        fee: Nat, timestamp: Time.Time
    ) {
        let index = opsWithDraw.size();
        let o : WithDrawRecord = {
            caller = caller;
            accountId = accountId;
            op = op;
            index = index;
            amount = amount;
            fee = fee;
            timestamp = timestamp;
        };
        opsWithDraw.put(index, o);
    };

    private func _addFee(from: Principal, fee: Nat) {
        if(fee > 0) {
            _transfer(from, feeTo, fee);
        };
    };

    // transfer WICP and deduct fee
    private func _transfer(from: Principal, to: Principal, value: Nat) {
        let from_balance = _balanceOf(from);
        let from_balance_new : Nat = from_balance - value;
        if (from_balance_new != 0) { balances.put(from, from_balance_new); }
        else { balances.delete(from); };

        let to_balance = _balanceOf(to);
        let to_balance_new : Nat = to_balance + value;
        if (to_balance_new > 0) { balances.put(to, to_balance_new); }
    };

    // user balance
    private func _balanceOf(who: Principal) : Nat {
        switch (balances.get(who)) {
            case (?balance) { return balance; };
            case (_) { return 0; };
        }
    };

    private func _allowance(owner: Principal, spender: Principal) : Nat {
        switch(allowances.get(owner)) {
            case (?allowance_owner) {
                switch(allowance_owner.get(spender)) {
                    case (?allowance) { return allowance; };
                    case (_) { return 0; };
                }
            };
            case (_) { return 0; };
        }
    };

    public shared(msg) func setStorageCanisterId(storage: ?Principal) : async Bool {
        assert(msg.caller == owner_);
        if (storage == null) { storageCanister := null; }
        else { storageCanister := ?actor(Principal.toText(Option.unwrap(storage))); };
        return true;
    };

    public shared(msg) func newStorageCanister(owner: Principal) : async Bool {
        assert(msg.caller == owner_ and storageCanister == null);
        let storage = await Storage.Storage(owner);
        storageCanister := ?storage;
        return true;
    };

    // set ledgerHistory canister id
    public shared(msg) func setLedHistoryCanisterId(ledgerHistoryId: Principal) : async Bool {
        assert(msg.caller == owner_);
        ledHistoryCanisterActor := actor(Principal.toText(ledgerHistoryId));
        return true;
    };

    public shared(msg) func setFee(_fee: Nat) : async Bool {
        assert(msg.caller == owner_);
        fee := _fee;
        return true;
    };

    public shared(msg) func setFeeTo(_feeTo: Principal) : async Bool {
        assert(msg.caller == owner_);
        feeTo := _feeTo;
        return true;
    };

    public shared(msg) func setMinBurnAmount(_amount: Nat) : async Bool {
        assert(msg.caller == owner_);
        minBurnAmount := _amount;
        return true;
    };

    public shared(msg) func setOwner(newOwner: Principal) : async Bool {
        assert(msg.caller == owner_);
        owner_ := newOwner;
        return true;
    };

    public shared(msg) func setDataUser(user: Principal) : async Bool {
        assert(msg.caller == owner_);
        dataUser := user;
        return true;
    };

    public shared(msg) func addAccountToReceiveArray(account: AccountIdentifier) : async Bool {

        assert(msg.caller == owner_);
        if( Option.isNull( Array.find<AccountIdentifier>(receiveICPAccArray, 
                            func (x : AccountIdentifier): Bool { x == account }) ) ){
            receiveICPAccArray := Array.append<AccountIdentifier>(receiveICPAccArray, Array.make(account));
        };
        return true;
    };

    public shared(msg) func clearWithDrawRecord(index: Nat) : async Bool {
        assert(msg.caller == owner_);
        for((k,v) in opsWithDraw.entries()){
            if(k < index){
                opsWithDraw.delete(k);
            };
        };
        return true;
    };

    /// Transfers value amount of tokens to Principal to.
    public shared(msg) func transfer(to: Principal, value: Nat) : async TransferResponse {
        assert(msg.caller != to);
        if (value < fee) { return #err(#LessThanFee); };
        if (_balanceOf(msg.caller) < value) { return #err(#InsufficientBalance); };
        _addFee(msg.caller, fee);
        _transfer(msg.caller, to, value - fee);

        let record = _genRecord(msg.caller, #transfer, ?msg.caller, ?to, value, fee, Time.now());
        if(storageCanister != null){
            ignore Option.unwrap(storageCanister).addRecord(record);
        };
        return #ok(record.index);
    };

    public shared(msg) func batchTransfer(tos: [Principal], values: [Nat]) : async TransferResponse {

        if (tos.size() != values.size() or tos.size() == 0 or values.size() == 0) { return #err(#Other); };

        var totalValue: Nat = 0;
        for(i in Iter.range(0, values.size() - 1)){
            totalValue := totalValue + values[i];
        };
        if (totalValue < fee) { return #err(#LessThanFee); };
        if (_balanceOf(msg.caller) < totalValue + fee) { return #err(#InsufficientBalance); };
        
        _addFee(msg.caller, fee);
        var trIndex: TransactionIndex = 0;
        let now = Time.now();
        var recordsList : List.List<OpRecord> = List.nil<OpRecord>();
        for(i in Iter.range(0, values.size() - 1)){
            _transfer(msg.caller, tos[i], values[i]);
            let record = _genRecord(msg.caller, #batchTransfer, ?msg.caller, ?tos[i], values[i], fee, now);
            trIndex := record.index;
            if(storageCanister != null){ recordsList := List.push<OpRecord>(record, recordsList); };
        };
        if(storageCanister != null){
            ignore Option.unwrap(storageCanister).addRecords(List.toArray(recordsList));
        };
        return #ok(trIndex);
    };

    /// Transfers value amount of tokens from Principal from to Principal to.
    public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat) : async TransferResponse {
        assert(msg.caller != from and from != to);
        if (value < fee) { return #err(#LessThanFee); };
        if (_balanceOf(from) < value) { return #err(#InsufficientBalance); };
        let allowed : Nat = _allowance(from, msg.caller);
        if (allowed < value) { return #err(#AllowedInsufficientBalance); };

        _addFee(from, fee);
        _transfer(from, to, value - fee);
        let allowed_new : Nat = allowed - value;
        if (allowed_new != 0) {
            let allowance_from = Option.unwrap(allowances.get(from));
            allowance_from.put(msg.caller, allowed_new);
            allowances.put(from, allowance_from);
        } else {
            if (allowed != 0) {
                let allowance_from = Option.unwrap(allowances.get(from));
                allowance_from.delete(msg.caller);
                if (allowance_from.size() == 0) { allowances.delete(from); }
                else { allowances.put(from, allowance_from); };
            };
        };

        let record = _genRecord(msg.caller, #transfer, ?from, ?to, value, fee, Time.now());
        if(storageCanister != null){
            ignore Option.unwrap(storageCanister).addRecord(record);
        };
        return #ok(record.index);
    };

    public shared(msg) func batchTransferFrom(from: Principal, tos: [Principal], values: [Nat]) : async TransferResponse {
        assert(msg.caller != from);
        if (tos.size() != values.size() or tos.size() == 0 or values.size() == 0) { return #err(#Other); };

        var totalValue: Nat = 0;
        for(i in Iter.range(0, values.size() - 1)){
            totalValue := totalValue + values[i];
        };
        if (totalValue < fee) { return #err(#LessThanFee); };
        if (_balanceOf(from) < totalValue + fee) { return #err(#InsufficientBalance); };
        let allowed : Nat = _allowance(from, msg.caller);
        if (allowed < totalValue + fee) { return #err(#AllowedInsufficientBalance); };

        _addFee(from, fee);
        var trIndex: TransactionIndex = 0;
        let now = Time.now();
        var recordsList : List.List<OpRecord> = List.nil<OpRecord>();
        for(i in Iter.range(0, values.size() - 1)){
            _transfer(from, tos[i], values[i]);
            let record = _genRecord(msg.caller, #batchTransfer, ?from, ?tos[i], values[i], fee, now);
            trIndex := record.index;
            if(storageCanister != null){ recordsList := List.push<OpRecord>(record, recordsList); };
        };
        if(storageCanister != null){
            ignore Option.unwrap(storageCanister).addRecords(List.toArray(recordsList));
        };
        let allowed_new : Nat = allowed - totalValue;
        if (allowed_new != 0) {
            let allowance_from = Option.unwrap(allowances.get(from));
            allowance_from.put(msg.caller, allowed_new);
            allowances.put(from, allowance_from);
        } else {
            if (allowed != 0) {
                let allowance_from = Option.unwrap(allowances.get(from));
                allowance_from.delete(msg.caller);
                if (allowance_from.size() == 0) { allowances.delete(from); }
                else { allowances.put(from, allowance_from); };
            };
        };
        return #ok(trIndex);
    };

    /// Allows spender to withdraw from your account multiple times, up to the value amount. 
    /// If this function is called again it overwrites the current allowance with value.
    public shared(msg) func approve(spender: Principal, value: Nat) : async Nat {
        assert(msg.caller != spender);
        if (value == 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Option.unwrap(allowances.get(msg.caller));
            allowance_caller.delete(spender);
            if (allowance_caller.size() == 0) { allowances.delete(msg.caller); }
            else { allowances.put(msg.caller, allowance_caller); };
        } else if (value != 0 and Option.isNull(allowances.get(msg.caller))) {
            var temp = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
            temp.put(spender, value);
            allowances.put(msg.caller, temp);
        } else if (value != 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Option.unwrap(allowances.get(msg.caller));
            allowance_caller.put(spender, value);
            allowances.put(msg.caller, allowance_caller);
        };

        return opsIndex;
    };

    /// Creates value WICP tokens and assigns them to user when receive ICP from User, increasing the total supply.
    public shared(msg) func mint(trxRecord: ICPTransactionRecord): async MintResponse {
        switch(mintBlockHeightMap.get(trxRecord.blockHeight)){
            case(?b){ return #err(#AlreadyMint);};
            case _ {};
        };
        switch(mintInfoMap.get(trxRecord.blockHeight)){
            case(?b){ return #err(#AlreadyMint);};
            case _ {};
        };
        
        var from: AccountIdentifier = AID.fromPrincipal(msg.caller, trxRecord.from_subaccount);
        let result = await ledHistoryCanisterActor.block(trxRecord.blockHeight);
        var amount: ICPTs = {e8s = 0;};
        switch(result){
            case(#Ok(res)) {
                switch(res){
                    case(#Ok(block)){
                        switch(block.transaction.transfer){
                            case(#Send(send)){
                                if(from != send.from or 
                                  Option.isNull(Array.find<AccountIdentifier>(receiveICPAccArray, func (x : AccountIdentifier): Bool { x == send.to }))){
                                      return #err(#NotRecharge);
                                };
                                amount := send.amount;
                            };
                            case (_){return #err(#NotTransferType);};
                        };
                    };
                    case(#Err(errStr)){return #err(#BlockError(errStr))};
                };
            };
            case(#Err(text)){return #err(#BlockError(text));};
        };

        let resAmount: Nat = Nat64.toNat(amount.e8s);
        switch(balances.get(msg.caller)){
            case(?b){
                balances.put(msg.caller, b + resAmount);
            };
            case _ {balances.put(msg.caller, resAmount);};
        };
        totalSupply_ += resAmount;
        //mintBlockHeightMap.put(trxRecord.blockHeight, true);
        let minInfo = {
            principalId = msg.caller;
            accountId = from;
            amount = resAmount;
        };
        mintInfoMap.put(trxRecord.blockHeight, minInfo);

        let record = _genRecord(msg.caller, #mint, null, ?msg.caller, resAmount, 0, Time.now());
        if(storageCanister != null){
            ignore Option.unwrap(storageCanister).addRecord(record);
        };
        return #ok(record.index);
    };

    //burn amount WICP tokens from msg.caller
    public shared(msg) func burn(amount: Nat): async BurnResponse {
        let balance = _balanceOf(msg.caller);
        if(amount < minBurnAmount) {return #err(#LessThanMinBurnAmount);};
        if(balance < amount + fee){ return #err(#InsufficientBalance);};
        balances.put(msg.caller, balance - amount);
        _addFee(msg.caller, fee);
        totalSupply_ := totalSupply_ - amount - fee;

        let record = _genRecord(msg.caller, #burn, ?msg.caller, null, amount, fee, Time.now());
        if(storageCanister != null){
            ignore Option.unwrap(storageCanister).addRecord(record);
        };
        
        var accountId: AccountIdentifier = AID.fromPrincipal(msg.caller, null);
        _addWithDrawRecord(msg.caller, accountId, #burn, amount, fee, Time.now());
        return #ok(record.index);
    };

    public shared(msg) func wallet_receive() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        return accepted;
    };

    public query func getMintInfo(blockNum: BlockHeight) : async ?MintInfo {
        mintInfoMap.get(blockNum)
    };

    public shared query(msg) func getAllMintInfo() : async [(BlockHeight ,MintInfo)] {
        assert(msg.caller == owner_);
        Iter.toArray(mintInfoMap.entries())
    };

    public query func balanceOf(who: Principal) : async Nat {
        return _balanceOf(who);
    };

    public query func getReceiveICPAcc() : async [AccountIdentifier] {
        return receiveICPAccArray;
    };

    public query func allowance(owner: Principal, spender: Principal) : async Nat {
        return _allowance(owner, spender);
    };

    public query func totalSupply() : async Nat {
        return totalSupply_;
    };

    public query func name() : async Text {
        return name_;
    };

    public query func getStorageCanisterId() : async ?Principal {
        var token:?Principal = null;
        if(storageCanister != null){
            token := ?Principal.fromActor(Option.unwrap(storageCanister));
        };
        return token;
    };

    public query func decimals() : async Nat {
        return decimals_;
    };

    public query func symbol() : async Text {
        return symbol_;
    };

    public query func owner() : async Principal {
        return owner_;
    };

    public query func getFeeTo() : async Principal {
        return feeTo;
    };

    public query func getFee() : async Nat {
        return fee;
    };

    public query func getUserNumber() : async Nat {
        return balances.size();
    };

    public query func getMinBurnAmount() : async Nat {
        return minBurnAmount;
    };

    public shared query(msg) func getAllBalance() : async [(Principal, Nat)] {
        assert(msg.caller == owner_);
        Iter.toArray(balances.entries())
    };

    public shared query(msg) func getWithDrawRecordByIndex(index: Nat) : async ?WithDrawRecord {
        assert(msg.caller == owner_ or msg.caller == dataUser);
        opsWithDraw.get(index)
    };

    public query func getWithDrawRecordSize(index: Nat) : async Nat {
        opsWithDraw.size()
    };

    public query(msg) func getWithDrawRecord(start: Nat, num: Nat) : async [WithDrawRecord] {
        assert(msg.caller == owner_ or msg.caller == dataUser);
        var ret: [WithDrawRecord] = [];
        label outer for(i in Iter.range(start, start + num - 1)){
            switch(opsWithDraw.get(i)){
                case (?w){
                    ret := Array.append(ret, [w]);
                };
                case _ {break outer;};
            };
        };
        return ret;
    };
    
    public query func getCycles() : async Nat {
        return Cycles.balance();
    };

    system func preupgrade() {
        balanceEntries := Iter.toArray(balances.entries());
        mintBlockHeightEntries := Iter.toArray(mintBlockHeightMap.entries());
        mintInfoEntries := Iter.toArray(mintInfoMap.entries());
        opsWithDrawEntries := Iter.toArray(opsWithDraw.entries());
    };

    system func postupgrade() {
        balances := HashMap.fromIter<Principal, Nat>(balanceEntries.vals(), 1, Principal.equal, Principal.hash);
        balanceEntries := [];

        mintBlockHeightMap := HashMap.fromIter<BlockHeight, Bool>(mintBlockHeightEntries.vals(), 1, Types.BlockHeight.equal, Types.BlockHeight.hash);
        mintBlockHeightEntries := [];

        mintInfoMap := HashMap.fromIter<BlockHeight, MintInfo>(mintInfoEntries.vals(), 1, Types.BlockHeight.equal, Types.BlockHeight.hash);
        mintInfoEntries := [];

        opsWithDraw := HashMap.fromIter<RecordIndex, WithDrawRecord>(opsWithDrawEntries.vals(), 1, Types.RecordIndex.equal, Types.RecordIndex.hash);
        opsWithDrawEntries := [];
    };
};
