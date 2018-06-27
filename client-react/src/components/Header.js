import React from 'react';
import gql from 'graphql-tag';
import logo from '../logo.svg';
import { Link } from 'react-router-dom';

export default class Header extends React.Component {
  static UserFragment = gql`
    fragment Header_UserFragment on User {
      nodeId
      id
      name
      isAdmin
    }
  `;

  renderUser() {
    if (this.props.user) {
      const username = this.props.user.name || `User ${this.props.user.id}`;
      return (
        <span>Logged in as {username}; <a href="/logout">Log out</a></span>
      );
    } else if (this.props.loading) {
      return null;
    } else if (this.props.error) {
      return null;
    } else {
      return (
        <Link to="/login">Log in</Link>
      );
    }
  }
  render() {
    return (
      <header className="Header">
        <div className="Header-titleContainer">
          <img src={logo} className="Header-logo" alt="logo" />
          <span className="Header-title">PostGraphile Forum Demo</span>
        </div>
        <div>
          {this.renderUser()}
        </div>
      </header>
    );
  }
}

