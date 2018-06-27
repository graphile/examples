import React from "react";
import { Redirect } from "react-router-dom";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";

export default class LoginPage extends React.Component {
  static QueryFragment = gql`
    fragment LoginPage_QueryFragment on Query {
      currentUser {
        nodeId
      }
    }
  `;

  static propTypes = {
    data: propType(LoginPage.QueryFragment),
  };

  render() {
    const { loading, error, currentUser } = this.props.data;
    if (loading) {
      return <div>Loading...</div>;
    }
    if (error) {
      return <div>Error {error.message}</div>;
    }
    if (currentUser) {
      return <Redirect to="/" />;
    } else {
      return (
        <div>
          <h1>Log in</h1>
          <p>
            With <a href="/auth/github">GitHub</a>
          </p>
        </div>
      );
    }
  }
}
