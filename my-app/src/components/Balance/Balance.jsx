import React, { Component } from 'react';
import styled from 'styled-components';


const MainDiv = styled.div`
    padding: 1.5rem;
    width: 40%;
    align-items: center;
    justify-content: center;
    border-radius: 20px;
    box-shadow: 1px 1px 11px 0px #b406c4;
`;

const Div = styled.div`
 display : flex;
`;

const H5 = styled.h5`
text-align: center;
padding-bottom: 1.5rem;
`;

const Input = styled.input`
text-align: center;
color: #b406c4;
`;

const Button = styled.button`
   background-color: white;
   border : 1px solid #b406c4;
   border-radius: 10px;
   color: #b406c4;
`;

const ButtonDiv = styled.div`
  margin-top: 1.5rem;
`;

export default class Balance extends Component {
    constructor (props){
      super(props);
      this.textInput = React.createRef();
      this.state ={
        balance : 0,
      };
    }
    
    getBalance = async (event) => {
       await this.setState({balance: event.target.value});
    }

    MouseOver = (event) =>{
        event.target.style.background = '#dd32ed';
        event.target.style.color='white';
    }

    MouseOut = (event) =>{
        event.target.style.background="";
        event.target.style.color='#b406c4';
    }
    
    handleDeposit = () => {
        const {balance} = this.state;
        this.props.deposit(balance).catch(this.props.logError)
    }

    handleWithdraw = () =>{
       this.props.withdraw(this.textInput.current.value).catch(this.props.logError)
    }

    handleClick = (e) => {
        e.preventDefault();
        this.textInput.current.value = this.props.renBTC;
        console.log("this.textInput.current.value: " + this.textInput.current.value);
    }

    render() {
        const {balance} = this.state;
        return (
            <div className='container'>
                <Div className='justify-content-around'>
               
                    <MainDiv>
                      <H5>Deposit BTC</H5>
                      <Input type="number" 
                             className="form-control" 
                             placeholder="Enter Amount" 
                             id="depositAmt"
                             onChange = {this.getBalance}/>
                      <ButtonDiv
                       style = {{textAlign: 'center'}}> 
                        <Button className='btn' 
                                onMouseOver={this.MouseOver} 
                                onMouseOut={this.MouseOut}
                                onClick={this.handleDeposit}>
                                Deposit {balance} BTC
                        </Button>
                      </ButtonDiv>
                    </MainDiv>
                   
                  
                   <MainDiv>
                    <H5>Withdraw BTC</H5>
                    <div style= {{display: 'flex'}}>
                    <Input ref={ this.textInput }
                           type="number" 
                           className="form-control" 
                           placeholder="Enter Amount" 
                           id="withdrawAmt"
                           style = {{marginRight: '0.5rem'}}/>
                     <Button onClick={this.handleClick} disabled={this.props.disable}>Max</Button>
                    </div>
                    <ButtonDiv style = {{textAlign: 'center'}}>
                        <Button className='btn' 
                                onMouseOver={this.MouseOver} 
                                onMouseOut={this.MouseOut}
                                onClick={this.handleWithdraw}
                                disabled={this.props.disable}>
                            Withdraw BTC
                        </Button>
                    </ButtonDiv>
                   </MainDiv>
                </Div>
                
                {/* <Button className='btn' onClick={this.props.handleCRVBalance}>Refresh Balance</Button>
                Balance : {this.props.crvBalance} Wei
                <p>
                <button onClick={() => this.deposit().catch(this.logError)}>
                    Deposit 0.002 BTC
                </button>
                </p>
                <p>
                <button onClick={() => this.withdraw().catch(this.logError)}>
                    Withdraw {this.props.crvBalance} BTC
                </button>
                </p> */}
            </div>
        )
    }
}
