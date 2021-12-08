# WICP
motoko code for a Wrapped ICP token canister on DFINITY's IC

## Summary

Currently, for security reasons, only NNS Canisters and users may hold ICP tokens on dfinity, The limitation caused a lot of difficulties, for example;  buy nft in the marketplace https://entrepot.app/, when user click buyNow, need to locked the seller's nft 5min first, and then transfer buyer's ICP, platform will transfer nft to buyer when icp transfer success. if icp transfer failed, the nft always locked 5min.

## Solution

Issue a contract Token that wrapped ICP, when received some ICP from user, mint same amount WICP token to user's principal Id automatically, and send same amount ICP to user's account-id when user burn some WICP automatically.

## Principle

* user transfer ICP to accoun-id which offered that define in the code of WICP, answer contain the blockheight when transfer success 
* user invoke "mint" function of WICP's canister, code will get the tx record use blockheight from ic network, and check the infomation, it will mint same amount WICP to user's principal-id if params pass the verification
* invoke "burn" function of WICP's canister if user want to convert WICP to ICP, script will get the burn-tx record from WICP canister, and check the infomation, send same amount icp to user's icp account automatically.

## Software versions
* dfx version 0.8.0
* Rust version 1.53.0
* NodeJS (with npm) version TBD


## Run IC

To build the code, proceed as follows after cloning the repository
```go
npm install
dfx build --network ic
dfx deploy --network ic
dfx canister  call WICP_motoko addAccountToReceiveArray "\"Receiving Account\""
dfx ledger --network ic transfer 8cd4e05794fdcdc37e5ece020d9d5daf01a3987a3869cbbe61a62f87f7773a1e --memo 1234 --amount 0.4999
Transfer sent at BlockHeight: 337756

dfx canister --network ic call WICP_motoko mint '(record {blockHeight=337756:nat64})'
(variant { ok = 49_990_000 : nat })
```
