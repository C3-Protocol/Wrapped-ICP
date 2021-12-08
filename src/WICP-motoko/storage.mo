/**
 * Module     : storage.mo
 * Copyright  : 2021 Hellman Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Hellman Team - Leven
 * Stability  : Experimental
 */

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Types "./common/types";
import Cycles "mo:base/ExperimentalCycles";

shared(msg) actor class Storage(_owner: Principal) {
    type Operation = Types.Operation;
    type OpRecord = Types.OpRecord;
    type RecordIndex = Types.RecordIndex;

    private stable var owner_ : Principal = _owner;
    private stable var token_canister_id_ : Principal = msg.caller;

    private stable var opsEntries : [(RecordIndex, OpRecord)] = [];
    private var ops = HashMap.HashMap<RecordIndex, OpRecord>(1, Types.RecordIndex.equal, Types.RecordIndex.hash);

    private stable var opsAccEntries: [(Principal, [RecordIndex])] = [];
    type ListRecord = List.List<RecordIndex>;
    private var opsAcc = HashMap.HashMap<Principal, ListRecord>(1, Principal.equal, Principal.hash);

    private stable var dataUser : Principal = Principal.fromText("umgol-annoi-q7dqt-qbsw6-a2pww-eitzs-6vi5t-efaz6-xquey-5jmut-sqe");

    system func preupgrade() {
        var size = opsAcc.size();
        var temp1 : [var (Principal, [RecordIndex])] = Array.init<(Principal, [RecordIndex])>(size, (owner_, []));
        size := 0;
        for ((k, v) in opsAcc.entries()) {
            temp1[size] := (k, List.toArray(v));
            size += 1;
        };
        opsAccEntries := Array.freeze(temp1);

        opsEntries := Iter.toArray(ops.entries());
    };

    system func postupgrade() {
        for ((k, v) in opsAccEntries.vals()) {
            opsAcc.put(k, List.fromArray<RecordIndex>(v));
        };
        opsAccEntries := [];

        ops := HashMap.fromIter<RecordIndex, OpRecord>(opsEntries.vals(), 1, Types.RecordIndex.equal, Types.RecordIndex.hash);
        opsEntries := [];
    };

    public shared(msg) func setTokenCanisterId(token: Principal) : async Bool {
        assert(msg.caller == owner_);
        token_canister_id_ := token;
        return true;
    };

    public query func getTokenCanisterId() : async Principal {
        token_canister_id_
    };

    public shared(msg) func setDataUser(user: Principal) : async Bool {
        assert(msg.caller == owner_);
        dataUser := user;
        return true;
    };

    public shared(msg) func addRecord( record: OpRecord ) : async Bool {
        assert( msg.caller == token_canister_id_);
        if(Option.isNull(ops.get(record.index))){
            ops.put(record.index, record);
            _addAccRecord(record);
        };
        return true;
    };

    public shared(msg) func addRecords( records: [OpRecord] ) : async Bool {
        assert( msg.caller == token_canister_id_ and records.size() > 0 );
        for(record in Iter.fromArray(records)) {
            if(Option.isNull(ops.get(record.index))){
                ops.put(record.index, record);
                _addAccRecord(record);
            };
        };
        return true;
    };

    private func _checkPrincipal(id: Principal) : Bool {
        var ret:Bool = false;
        if(Principal.toText(id).size() > 60){
            ret := true;
        };
        return ret;
    };

    private func _addAccRecord( o: OpRecord ) {
        if (_checkPrincipal(o.caller)) { _putOpsAcc(o.caller, o.index); };
        if (Option.isSome(o.from) and (o.from != ?o.caller) and _checkPrincipal(Option.unwrap(o.from))) { _putOpsAcc(Option.unwrap(o.from), o.index); };
        if (Option.isSome(o.to) and (o.to != ?o.caller) and (o.to != o.from) and _checkPrincipal(Option.unwrap(o.to))) { _putOpsAcc(Option.unwrap(o.to), o.index); };
    };

    private func _putOpsAcc(who: Principal, index: RecordIndex) {
        switch (opsAcc.get(who)) {
            case (?l) {
                let newl = List.push<RecordIndex>(index, l);
                opsAcc.put(who, newl);
            };
            case (_) {
                let l1 = List.nil<RecordIndex>();
                let l2 = List.push<RecordIndex>(index, l1);
                opsAcc.put(who, l2);
            };   
        }
    };

    /// Get history
    public shared query(msg) func getHistory(start: Nat, num: Nat) : async [OpRecord] {
        assert( msg.caller == owner_ or msg.caller == dataUser );
        
        var ret: List.List<OpRecord> = List.nil<OpRecord>();
        var index = start;
        while( Option.isSome(ops.get(index)) and index < start + num ) {
            //ret := Array.append(ret, [Option.unwrap(ops.get(index))]);
            ret := List.push(Option.unwrap(ops.get(index)), ret);
            index += 1;
        };
        return List.toArray(ret);
    };

    public query func getHistoryByAccount(user: Principal) : async [OpRecord] {

        var ret: List.List<OpRecord> = List.nil<OpRecord>();
        switch ( opsAcc.get(user) ) {
            case (?op_acc) {
                List.iterate<RecordIndex>(op_acc, func (x : RecordIndex): () { 
                    if(Option.isSome(ops.get(x))){
                        ret := List.push(Option.unwrap(ops.get(x)), ret); 
                    };
                });
            };
            case (_) {};   
        };
        return List.toArray(ret);
    };

    public query func getOpsSize() : async Nat {
        ops.size()
    };
    
    public query func getCycles() : async Nat {
        return Cycles.balance();
    };

    public shared(msg) func wallet_receive() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        return accepted;
    };

};