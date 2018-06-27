import React from "react";
import gql from "graphql-tag";
import logo from "../logo.svg";
import { Link } from "react-router-dom";
import { propType } from "graphql-anywhere";
import PropTypes from "prop-types";

export default class Header extends React.Component {
  static UserFragment = gql`
    fragment Header_UserFragment on User {
      nodeId
      id
      name
      isAdmin
    }
  `;

  static propTypes = {
    user: propType(Header.UserFragment),
    loading: PropTypes.bool,
    error: PropTypes.object,
  };

  renderUser() {
    const { user, loading, error } = this.props;
    if (user) {
      const username = user.name || `User ${user.id}`;
      return (
        <span>
          Logged in as {user.isAdmin ? "administrator" : ""} {username};{" "}
          <a href="/logout">Log out</a>
        </span>
      );
    } else if (loading) {
      return null;
    } else if (error) {
      return null;
    } else {
      return <Link to="/login">Log in</Link>;
    }
  }

  render() {
    return (
      <header className="Header">
        <div className="Header-titleContainer">
          <img src={logo} className="Header-logo" alt="logo" />
          <span className="Header-title">PostGraphile Forum Demo</span>
        </div>
        <div>{this.renderUser()}</div>
      </header>
    );
  }
}
