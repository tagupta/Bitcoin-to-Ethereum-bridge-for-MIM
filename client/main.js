
var web3 = new Web3(Web3.givenProvider);    
var instance;
var balance = 0;
const contractAddress = '0x433aa3BF6A85dD1eA9801078c0334610F97038e5';
//const renJS =  new RenJS("testnet", { useV2TransactionFormat: true });

$(document).ready(async()=>{
    try{
        window.ethereum.enable().then((accounts)=>{
            instance = new web3.eth.Contract(abi,contractAddress,{from: accounts[0]});
            console.log(instance);
          })
    }catch{
      alert('Please allow access to your Web3 wallet');
    }
    const networkID = await web3.eth.net.getId();
    if (networkID !== 42) {
       alert("Please set your network to Kovan.");
       return;
    }
  
});

async function updateBalance(){
    balance = await instance.methods.balance().call();
    console.log(balance);
    $('#btnBalance').html(balance);
}

async function deposit(){

console.log(`Generating deposit address...`);

const amount = 0.002; // BTC
const mint = await renJS.lockAndMint({
  // Send BTC from the Bitcoin blockchain to the Ethereum blockchain.
  asset: "BTC",
  from: Bitcoin(),
  to: Ethereum(window.ethereum).Contract({
    // The contract we want to interact with
    sendTo: contractAddress,

    // The name of the function we want to call
    contractFn: "deposit",

    // Arguments expected for calling `deposit`
    contractParams: [
      {
        name: "_msg",
        type: "bytes",
        value: Buffer.from(`Deposit ${amount} BTC to ${mint.gatewayAddress}`),
      },
    ],
  }),
});

console.log(`Deposit ${amount} BTC to ${mint.gatewayAddress}`);

mint.on("deposit", async (deposit) => {
    // Details of the deposit are available from `deposit.depositDetails`.
  
    const hash = deposit.txHash();
    const depositLog = (msg) =>
      console.log(
        `BTC deposit: ${Bitcoin.utils.transactionExplorerLink(
          deposit.depositDetails.transaction,
          "testnet"
        )}\n
        RenVM Hash: ${hash}\n
        Status: ${deposit.status}\n
        ${msg}`
      );
  
    await deposit
      .confirmed()
      .on("target", (target) => depositLog(`0/${target} confirmations`))
      .on("confirmation", (confs, target) =>
        depositLog(`${confs}/${target} confirmations`)
      );
  
    await deposit
      .signed()
      // Print RenVM status - "pending", "confirming" or "done".
      .on("status", (status) => depositLog(`Status: ${status}`));
  
    await deposit
      .mint()
      // Print Ethereum transaction hash.
      .on("transactionHash", (txHash) =>
        this.log(`Ethereum transaction: ${String(txHash)}\nSubmitting...`)
      );
  
    console.log(`Deposited ${amount} BTC.`);
  });
}

async function withdraw(){

const recipient = prompt("Enter BTC recipient:");
const amount = balance;
const burnAndRelease = await renJS.burnAndRelease({
  // Send BTC from Ethereum back to the Bitcoin blockchain.
  asset: "BTC",
  to: Bitcoin().Address(recipient),
  from: Ethereum(window.ethereum).Contract((btcAddress) => ({
    sendTo: contractAddress,
    contractFn: "withdraw",
    contractParams: [
      {
        type: "bytes",
        name: "_msg",
        value: Buffer.from(`Withdrawing ${amount} BTC`),
      },
      {
        type: "bytes",
        name: "_to",
        value: Buffer.from(btcAddress),
      },
      {
        type: "uint256",
        name: "_amount",
        value: RenJS.utils.toSmallestUnit(amount, 8),
      },
    ],
  })),
});

let confirmations = 0;
await burnAndRelease
  .burn()
  // Ethereum transaction confirmations.
  .on("confirmation", (confs) => {
    confirmations = confs;
  })
  // Print Ethereum transaction hash.
  .on("transactionHash", (txHash) => console.log(`txHash: ${String(txHash)}`));

await burnAndRelease
  .release()
  // Print RenVM status - "pending", "confirming" or "done".
  .on("status", (status) =>
    status === "confirming"
      ? console.log(`${status} (${confirmations}/15)`)
      : console.log(status)
  )
  // Print RenVM transaction hash
  .on("txHash", console.log(txHash));

 console.log(`Withdrew ${amount} BTC to ${recipient}.`);
}