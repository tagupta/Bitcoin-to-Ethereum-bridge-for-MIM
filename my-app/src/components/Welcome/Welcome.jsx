import React, { Component } from 'react';
import Button from '@mui/material/Button';
import Dialog from '@mui/material/Dialog';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import DialogContentText from '@mui/material/DialogContentText';
import DialogTitle from '@mui/material/DialogTitle';

import './Welcome.css';

export default class Welcome extends Component {
  constructor(props){
   super(props);
   this.state = {
     open : true,
   };
  }

  handleClose = () => {
   this.setState({open: false});
  }

  render() {
    const {open} = this.state;
    return (
          <div>
            <Dialog open={open}
                    onClose={this.handleClose}
                    aria-labelledby="alert-dialog-title"
                    aria-describedby="alert-dialog-description">
                <DialogTitle id="alert-dialog-title">
                <strong><p id='modalTitle'>{"Guidelines for using this Dapp"}</p></strong>
                </DialogTitle>
                <DialogContent>
                    <DialogContentText id="alert-dialog-description">
                        
                           <strong style={{color:"#b406c4"}}>Description of the dapp:</strong><br></br>
                           Deposit BTC to borrow MIM and 
                           Repay MIM to get BTC back.
                           <br></br><br></br>
                           <strong style={{color:"#b406c4"}}>Instructions:</strong><br></br>
                           You are encouraged to use sufficient funds to use the dapp seamlessly.  <br></br>
                           You are advised to sign transactions as soon as the metamask window pops up.
                        
                    </DialogContentText>
                </DialogContent>
                <DialogActions>
                    <Button id='buttonText' onClick={this.handleClose} autoFocus>Agree</Button>
                </DialogActions>
            </Dialog>
          </div>
        );
  }
}
