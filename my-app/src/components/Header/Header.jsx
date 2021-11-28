import React, { Component } from 'react'
import styled from 'styled-components';

const AppHeader = styled.header`
    min-height: 20vh;
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: center;
    color: #b406c4;
    font-family: monospace;
`;

const H1 = styled.h1`
font-size: 36px;
`;
export default class Header extends Component {
    render() {
        return (
            <AppHeader>
            <H1>
                Defi Journey from BTC to CRV
            </H1>
            </AppHeader>
        )
    }
}
