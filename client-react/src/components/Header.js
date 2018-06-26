import React from 'react';
import gql from 'graphql-tag';
import logo from '../logo.svg';

export default class Header extends React.Component {
  static UserFragment = gql`
    fragment Header_UserFragment on User {
      nodeId
      id
      name
      isAdmin
    }
  `;
  render() {
    return (
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <h1 className="App-title">Welcome to PostGraphile Forum Demo</h1>
      </header>
    );
  }
}

