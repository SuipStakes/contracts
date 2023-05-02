import {
  Connection,
  Ed25519Keypair,
  JsonRpcProvider,
  RawSigner,
  TransactionBlock,
} from '@mysten/sui.js';
import "dotenv/config";
import { execSync } from "child_process";
import fetch from "node-fetch";

globalThis.fetch = fetch;

const cliPath = "sui"
const packagePath = "../contracts"

if (process.env.RECOVERY_PHRASE == undefined) {
  console.error('PK not set');
  exit(1);
}

const RECOVERY_PHRASE = process.env.RECOVERY_PHRASE;

// Generate a new Keypair
const keypair = Ed25519Keypair.deriveKeypair(RECOVERY_PHRASE);
// Construct your connection:
const connection = new Connection({
  fullnode: 'https://rpc.ankr.com/sui_testnet',
});
// connect to a custom RPC server
const provider = new JsonRpcProvider(connection);
// // connect to devnet
// const provider = new JsonRpcProvider();
const signer = new RawSigner(keypair, provider);
const { modules, dependencies } = JSON.parse(
  execSync(
    `${cliPath} move build --dump-bytecode-as-base64 --path ${packagePath}`,
    { encoding: 'utf-8' },
  ),
);
const tx = new TransactionBlock();
const [upgradeCap] = tx.publish({
  modules,
  dependencies,
});
tx.transferObjects([upgradeCap], tx.pure(await signer.getAddress()));
const result = await signer.signAndExecuteTransactionBlock({
  transactionBlock: tx,
});
console.log({ result });