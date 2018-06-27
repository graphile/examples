import React from "react";
import { Link } from "react-router-dom";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";

export default class HomePage extends React.Component {
  static QueryFragment = gql`
    fragment HomePage_QueryFragment on Query {
      currentUser {
        id
      }
    }
  `;

  static propTypes = {
    data: propType(HomePage.QueryFragment),
  };

  render() {
    const { data } = this.props;
    const { loading, error, currentUser } = data;
    if (loading) {
      return <div>Loading...</div>;
    }
    if (error) {
      return <div>Error {error.message}</div>;
    }
    if (currentUser) {
      return <div>Logged in as user {currentUser.id}</div>;
    } else {
      return (
        <div>
          To log in, <Link to="/login">click here</Link>
        </div>
      );
    }
  }
}
