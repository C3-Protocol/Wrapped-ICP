use serde::{Deserialize, Serialize};
use candid::CandidType;
use dfn_candid::{candid, candid_one};
use dfn_core::{api::call_with_cleanup, over, over_async};
use dfn_core::api::{msg_cycles_available, msg_cycles_accept, canister_cycle_balance};
use dfn_protobuf::protobuf;
use ic_nns_constants::LEDGER_CANISTER_ID;
use ic_types::CanisterId;
use ledger_canister::{
    protobuf::TipOfChainRequest, Block, BlockArg, BlockHeight, BlockRes, TipOfChainRes, EncodedBlock,
};

#[export_name = "canister_update block"]
fn block() {
    over_async(candid_one, |height: u64| get_block(height))
}

async fn call_block_pb(canister_id: CanisterId, method: &str, height: u64) -> Result<Result<EncodedBlock, CanisterId>, String> {
    let BlockRes(res) = call_with_cleanup(canister_id, method, protobuf, BlockArg(height))
        .await
        .map_err(|e| format!("Failed to fetch block {}", e.1))?;
    let result = res.ok_or("Block not found")?;
    Ok(result)
}

async fn get_block(height: u64) -> Result<Result<Block, String>, String> {
    let block_info = call_block_pb(LEDGER_CANISTER_ID, "block_pb", height).await?;
    match block_info {
        Ok(raw_block) => {
            let block = raw_block.decode().unwrap();
            Ok(Ok(block))
        }
        Err(canister_id) => {
            let block_info = call_block_pb(canister_id, "get_block_pb", height).await?;
            match block_info {
                Ok(raw_block) => {
                    let block = raw_block.decode().unwrap();
                    Ok(Ok(block))
                }
                Err(canister_id) => Ok(Err(format!("call canister failed,{}", canister_id.to_string())))
            }
        }
    }
}

#[derive(Serialize, Deserialize, CandidType, Clone, Hash, Debug, PartialEq, Eq)]
pub struct TipOfChain {
    pub certification: Option<Vec<u8>>,
    pub tip_index: BlockHeight,
}

#[export_name = "canister_update tip_of_chain"]
fn tip_of_chain() {
    over_async(candid, |()| get_tip_of_chain())
}

async fn get_tip_of_chain() -> Result<TipOfChain, String> {
    let result: TipOfChainRes = call_with_cleanup(
        LEDGER_CANISTER_ID,
        "tip_of_chain_pb",
        protobuf,
        TipOfChainRequest {},
    )
    .await
    .map_err(|e| format!("Failed to get tip of chain {}", e.1))?;
    Ok(TipOfChain {
        certification: result.certification,
        tip_index: result.tip_index,
    })
}

#[export_name = "canister_update wallet_receive"]
fn wallet_receive() {
    over_async(candid, |()| donate_cycles())
}

async fn donate_cycles() -> u64 {
    let avaiable: u64 = msg_cycles_available();
    let accept: u64 = msg_cycles_accept(avaiable);
    accept
}

#[export_name = "canister_query get_cycles"]
fn get_cycles() {
    over(candid, |()| get_balance())
}

fn get_balance() -> u64 {
    let balance: u64 = canister_cycle_balance();
    balance
}

#[export_name = "canister_query __get_candid_interface_tmp_hack"]
fn expose_candid() {
    over(candid, |_: ()| {
        include_str!("./ledger_history.did").to_string()
    })
}