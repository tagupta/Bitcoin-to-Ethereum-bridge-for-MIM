import React from 'react';
import Web3 from "web3";
import Backdrop from '@mui/material/Backdrop';
import CircularProgress from '@mui/material/CircularProgress';
import 'bootstrap/dist/css/bootstrap.min.css';
import styled from 'styled-components';

import RenJS from "@renproject/ren";
import { Bitcoin, Ethereum } from "@renproject/chains";
import {utils} from 'ethers';

import ABI from "./json/ABI.json"; //json of basic contract
import RENERC20 from "./json/RenERC20.json";
import MoneyToCurve from './json/MoneytoCurve.json';

import Header from './components/Header/Header';
import Balance from './components/Balance/Balance';
import Message from './components/Message/Message';



// Replace with your contract's address.
const contractAddress = "0xFBDb93bC815dcc6F2c8Db8943AD8c75020E5083d"; // basic contract
const curveCRVAddress = "0xD096C904A48B8cE87207886297e0EDdeDcF84E94";
const defiAddress  = "0x908E71246FD4849280af70aaA2763A94D8d5c91d";
const wBTCAddress = "0xFDD470e97f2d51bF717c6e5201352fF6Ec6A2cc6";

const AppDiv = styled.div`
font-family: monospace;
color: #b406c4;
`;

class App extends React.Component{
  constructor(props){
    super(props);
    this.state = {
      balance : 0,        // web3 address  renAddress basicContract renBalance
      message : '',
      error : '',
      renJS: new RenJS("testnet", { useV2TransactionFormat: true }),
      isOpen: false,
      disableWithdraw: true,
    };
  }
  
  componentDidMount = async () =>{
    let web3Provider;
    if (window.ethereum) {
      web3Provider = window.ethereum;
      try {
        await window.ethereum.enable();
      } catch (error) {
        this.logError("Please allow access to your Web3 wallet.");
        return;
      }
    } else if (window.web3) {
      web3Provider = window.web3.currentProvider;
    }
    else {
      this.logError("Please install MetaMask!");
      return;
    }
    
    const web3 =  new Web3(web3Provider);
    const address = (await web3.eth.getAccounts())[0];
    const networkID = await web3.eth.net.getId();
    if (networkID !== 42) {
      this.logError("Please set your network to Kovan.");
      return;
    }
  
    this.setState({web3, address}, () => {
      this.updateBalance();
    });
  }

  updateBalance = async () => {
   
    const {web3} = this.state;
    const basicContract = new web3.eth.Contract(ABI, contractAddress);
    const renAddress = await basicContract.methods.getRenERC20().call();
  
    this.setState({renAddress , basicContract});
    console.log("After setting up the renAddress: "+ renAddress);
  }

  handleTBTCBalance = async () => {
    const {address, basicContract} = this.state;
    const balance = await basicContract.methods.userBalance(address).call();
    this.setState({balance: parseInt(balance.toString()) / 10 ** 8});
  }

  deposit = async (amount) => {
    const { address, web3, basicContract, renJS } = this.state;

    this.log(`Generating deposit address...`);
    const nonce = utils.keccak256(Buffer.from("1"));
    // const amount = 0.002;

    const mint = await renJS.lockAndMint({
      asset: "BTC",
      from: Bitcoin(),
      to: Ethereum(web3.currentProvider).Contract({
        sendTo: contractAddress,

        // The name of the function we want to call
        contractFn: "temporaryMint",

        // Arguments expected for calling `deposit`
        contractParams: [
          {
            name: "to",
            type: "address",
            value: address,
          },
          {
            name: "nonce",
            type: "bytes32",
            value: nonce,
          }
        ],
      }),
    });

    this.log(`Deposit ${amount} BTC to ${mint.gatewayAddress}`);

    mint.on("deposit", async (deposit) => {
    
      const hash = deposit.txHash();
      const depositLog = (msg) =>
        { 
          this.setState({isOpen: true});
          this.log(
            `BTC deposit: ${Bitcoin.utils.transactionExplorerLink(
              deposit.depositDetails.transaction,
              "testnet"
            )}\n
            RenVM Hash: ${hash}\n
            Status: ${deposit.status}\n
            ${msg}`
          );
        }
    
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
    
      const tx = await deposit.queryTx()
        if (tx.out && !tx.out.revert) {
          await basicContract.methods.temporaryMint(address, nonce, 'BTC', tx.out.amount.toString(), tx.out.nhash, tx.out.signature).send({from: address},(error,txHash)=>{
            if(error){
              this.logError(error);
              this.handleClose();
            }
            else{
              this.log('BTCs on ETH are minted');
              //here's the logic for calling the defi curve
              this.mintingCRV();
            }
          })
        } else {
          this.handleClose();
          throw new Error('revert was present on the out')
        }
    
      this.log(`Deposited ${amount} BTC.`);
    });
  }

  mintingCRV = async () => {
    const { address, web3, renAddress, basicContract } = this.state;

    console.log('CRV address: '+ curveCRVAddress);
    const renBalance = await basicContract.methods.userBalance(address).call();
    console.log('renBTC Balance after minting:' + renBalance / 10 ** 8);
    const renBTC = await new web3.eth.Contract(RENERC20, renAddress,{from: address});
    const wBTC = await new web3.eth.Contract(RENERC20, wBTCAddress, {from: address});
    const renBTCToCRV = await new web3.eth.Contract(MoneyToCurve,defiAddress,{from:address});
    this.setState({renBalance});
    await renBTC.methods.approve(defiAddress, renBalance).send({from: address},(error,txHash)=>{
      if(error){
          this.logError(error);
          this.handleClose();
      }
      else{
        this.log("Approval: 1/2");
      }
    });

    await wBTC.methods.approve(defiAddress,'100000000000000000000').send({from: address},(error,txHash)=>{
      if(error){
          this.logError(error);
          this.handleClose();
      }
      else{
         this.log("Approval: 2/2");
      }
    });

    await renBTCToCRV.methods.multiStepDeposit([renBalance,'100000000000000000000']).send({from: address},(error,txHash)=>{
      if(error){
        this.logError(error);
        this.handleClose();
      }
      else{
        this.setState({disableWithdraw: false});
        this.log('Please Check your wallet for CRV');
        this.handleClose();
      }
    });
  }

  withdraw = async(withdrawalAmt) =>{
    this.logError(""); // Reset error.

    const { address, web3, renAddress, renJS ,basicContract,renBalance} = this.state;

    if(withdrawalAmt <= renBalance){
      const renBal = await basicContract.methods.userBalance(address).call();
      console.log("renBal: " + renBal / 10 ** 8);
      console.log("renBalance from  withdraw: "+ renBalance);
      const renBTCToCRV = await new web3.eth.Contract(MoneyToCurve,defiAddress,{from:address});
      if(withdrawalAmt > 0){ // '100000000000000000000' 100000000
        await renBTCToCRV.methods.multiStepWithdraw([withdrawalAmt,'100000000']).send({from: address},(error,txHash)=>{
          if(error){
            this.logError(error);
          }
          else{
            this.log('CRVs are converted to renBTC');
          }
        });
      }
      else{
        alert('Please enter appropriate value for withdrawal');
        return;
      }
      
      const renBTC = await new web3.eth.Contract(RENERC20, renAddress,{from: address});
      await renBTC.methods.approve(contractAddress, renBalance).send({from:address},(error,txHash)=>{
        if(error){
          this.logError(error);
        }
        else{
          this.log('Approval: 1/1');
          console.log('Success: approval to basic contract by renBTC');
        }
      });
  
      const recipient = prompt("Enter BTC recipient:");
      this.setState({isOpen: true});
      const __amount = await basicContract.methods.userBalance(address).call();
      const amount = __amount / 10 ** 8;
  
      const burnAndRelease = await renJS.burnAndRelease({
        asset: "BTC",
        to: Bitcoin().Address(recipient),
        from: Ethereum(web3.currentProvider).Contract((btcAddress) => ({
          sendTo: contractAddress,
    
          contractFn: "temporaryBurn",
    
          contractParams: [
            {
              type: "bytes",
              name: "_msg",
              value: Buffer.from(`Withdrawing ${amount} BTC`),
            },
            {
              type: "bytes",
              name: "_to",
              value: btcAddress,
            },
            {
              type: "uint256",
              name: "_amount",
              value: renJS.utils.toSmallestUnit(amount, 8),
            },
            {
              type: 'address',
              name: 'from',
              value: address
            }
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
      .on("transactionHash", (txHash) => this.log(`txHash: ${String(txHash)}`));
  
      await burnAndRelease
        .release()
        // Print RenVM status - "pending", "confirming" or "done".
        .on("status", (status) =>
          status === "confirming"
            ? this.log(`${status} (${confirmations}/15)`)
            : this.log(status)
        )
        // Print RenVM transaction hash
        .on("txHash", this.log);
  
      this.log(`Withdrew ${amount} BTC to ${recipient}.`);
    }
    else{
      alert('Wrong input for withdrawal');
    }
    this.handleClose();
  }

  logError = (error) => {
  console.error(error);
  this.setState({error: String((error || {}).message || error)});
  };

  log = (message) => {
    this.setState({message});
  };

  handleClose = () => {
    this.setState({isOpen: false});
  };

  handleToggle = () => {
    const {isOpen}  = this.state;
    this.setState({isOpen: !isOpen});
  };

  render = () => {
    const { message, error, isOpen ,renBalance, disableWithdraw} = this.state;
    return (
      <AppDiv>
        <Header/>
        <Balance renBTC = {renBalance} 
                 handleCRVBalance = {this.handleCRVBalance} 
                 deposit = {this.deposit}
                 withdraw = {this.withdraw}
                 logError = {this.logError}
                 disable = {disableWithdraw}/> 

        <Message msg = {message} err = {error}/>

        <Backdrop sx={{ color: '#fff', zIndex: (theme) => theme.zIndex.drawer + 1 }}
                  open={isOpen}>
          <CircularProgress color="inherit" />
        </Backdrop>
          
      </AppDiv>
    );
  };

}
export default App;