import React from "react";
import Header from "../components/Header";

import gql from "graphql-tag";

const Empty = () => (
  <div>
    No <tt>bodyComponent</tt> provided
  </div>
);

export default class StandardLayout extends React.Component {
  static QueryFragment = gql`
    fragment StandardLayout_QueryFragment on Query {
      currentUser {
        ...Header_UserFragment
      }
    }
    ${Header.UserFragment}
  `;
  render() {
    const {
      graphql: { loading, error, data },
      bodyComponent: BodyComponent = Empty,
    } = this.props;

    return (
      <div>
        <Header
          loading={loading}
          error={error}
          user={data && data.currentUser}
        />
        <BodyComponent loading={loading} error={error} data={data} />
      </div>
    );
  }
}
