import React, { Component } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { Container } from '@mui/material';
import PropTypes from 'prop-types';
import { styled } from '@mui/material/styles';
import Stack from '@mui/material/Stack';
import Stepper from '@mui/material/Stepper';
import Step from '@mui/material/Step';
import StepLabel from '@mui/material/StepLabel';
import SettingsIcon from '@mui/icons-material/Settings';
import StepConnector, { stepConnectorClasses } from '@mui/material/StepConnector';
import AttachMoneyIcon from '@mui/icons-material/AttachMoney';
import AddTaskIcon from '@mui/icons-material/AddTask';
import './Message.css';

  const ColorlibConnector = styled(StepConnector)(({ theme }) => ({
    [`&.${stepConnectorClasses.alternativeLabel}`]: {
      top: 22,
    },
    [`&.${stepConnectorClasses.active}`]: {
      [`& .${stepConnectorClasses.line}`]: {
        backgroundImage:
          'linear-gradient( 95deg,rgb(242,113,33) 0%,rgb(233,64,87) 50%,rgb(138,35,135) 100%)',
      },
    },
    [`&.${stepConnectorClasses.completed}`]: {
      [`& .${stepConnectorClasses.line}`]: {
        backgroundImage:
          'linear-gradient( 95deg,rgb(242,113,33) 0%,rgb(233,64,87) 50%,rgb(138,35,135) 100%)',
      },
    },
    [`& .${stepConnectorClasses.line}`]: {
      height: 3,
      border: 0,
      backgroundColor:
        theme.palette.mode === 'dark' ? theme.palette.grey[800] : '#eaeaf0',
      borderRadius: 1,
    },
  }));

  const ColorlibStepIconRoot = styled('div')(({ theme, ownerState }) => ({
    backgroundColor: theme.palette.mode === 'dark' ? theme.palette.grey[700] : '#ccc',
    zIndex: 1,
    color: '#fff',
    width: 50,
    height: 50,
    display: 'flex',
    borderRadius: '50%',
    justifyContent: 'center',
    alignItems: 'center',
    ...(ownerState.active && {
      backgroundImage:
        'linear-gradient( 136deg, rgb(242,113,33) 0%, rgb(233,64,87) 50%, rgb(138,35,135) 100%)',
      boxShadow: '0 4px 10px 0 rgba(0,0,0,.25)',
    }),
    ...(ownerState.completed && {
      backgroundImage:
        'linear-gradient( 136deg, rgb(242,113,33) 0%, rgb(233,64,87) 50%, rgb(138,35,135) 100%)',
    }),
  }));

  function ColorlibStepIconDeposit(props) {
    const { active, completed, className } = props;
  
    const icons = {
       1: <AttachMoneyIcon/>,
       2: <AttachMoneyIcon/>,
       3: <SettingsIcon />,
       4: <AttachMoneyIcon/>,
       5: <AddTaskIcon/>,
    };
  
    return (
      <ColorlibStepIconRoot ownerState={{ completed, active }} className={className}>
        {icons[String(props.icon)]}
      </ColorlibStepIconRoot>
    );
  }

  ColorlibStepIconDeposit.propTypes = {
    active: PropTypes.bool,
    className: PropTypes.string,
    completed: PropTypes.bool,
    icon: PropTypes.node,
  };

  function ColorlibStepIconWithdraw(props){
    const { active, completed, className } = props;
  
    const icons = {
       1: <AttachMoneyIcon/>,
       2: <SettingsIcon/>,
       3: <AttachMoneyIcon/>,
       4: <AttachMoneyIcon/>,
       5: <AddTaskIcon/>,
    };
  
    return (
      <ColorlibStepIconRoot ownerState={{ completed, active }} className={className}>
        {icons[String(props.icon)]}
      </ColorlibStepIconRoot>
    );
  }

  ColorlibStepIconWithdraw.propTypes = {
    active: PropTypes.bool,
    className: PropTypes.string,
    completed: PropTypes.bool,
    icon: PropTypes.node,
  };
  
  const depositSteps = ['Deposit BTC', 'Lock and Mint renBTC', 'Approvals','Getting cvxrencrv from renBTC','Borrowing MIM'];
  const withdrawSteps = ['Repay MIM','Approvals','Getting cvxrencrv back from MIM','Getting renBTC back from cvxrencrv','Burn renBTC and release BTC']

export default class Message extends Component {
    render() {
        const {msg, err, activeSteps,action} = this.props;
        var container = "";
        if(action === 'deposit'){
            container = <><Stack sx={{ width: "100%" }} spacing={4}>
                        <Stepper alternativeLabel activeStep={activeSteps} connector={<ColorlibConnector />}>
                            {depositSteps.map((label) => (
                            <Step key={label}>
                                <StepLabel StepIconComponent={ColorlibStepIconDeposit}>{label}</StepLabel>
                            </Step>
                            ))}
                        </Stepper>
                    </Stack></>
            }
            else if(action === 'withdraw'){
                container = <><Stack sx={{ width: "100%" }} spacing={4}>
                <Stepper alternativeLabel activeStep={activeSteps} connector={<ColorlibConnector />}>
                    {withdrawSteps.map((label) => (
                    <Step key={label}>
                        <StepLabel StepIconComponent={ColorlibStepIconWithdraw}>{label}</StepLabel>
                    </Step>
                    ))}
                </Stepper>
            </Stack></>
            }
      
        return (
            <Container>
                <div className='justify-content-center messageBox'>
                    <br></br>
                    <p>Status Information</p>
                    <br></br>
                    {msg.split("\n").map((line) => (
                    <p key={uuidv4()}>{line}</p>
                    ))}
                    {err ? <p style={{ color: "red" }}>{err}</p> : null}
                    {container}
                </div>
            </Container>
             
        )
    }
    }
