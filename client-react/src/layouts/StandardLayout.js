import React from "react";
import Header from "../components/Header";
import { propType } from "graphql-anywhere";
import PropTypes from "prop-types";

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

  static propTypes = {
    data: propType(StandardLayout.QueryFragment),
    bodyComponent: PropTypes.func,
  };

  render() {
    const { data, bodyComponent: BodyComponent = Empty } = this.props;
    const { loading, error, currentUser } = data;

    return (
      <div>
        <Header loading={loading} error={error} user={currentUser} />
        <BodyComponent data={data} />
      </div>
    );
  }
}
