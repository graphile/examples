import React from "react";
import gql from "graphql-tag";
import { Query } from "react-apollo";
import StandardLayout from "../layouts/StandardLayout";
import LoginPage from "../components/LoginPage";

const LoginQuery = gql`
  query LoginQuery {
    ...StandardLayout_QueryFragment
    ...LoginPage_QueryFragment
  }
  ${StandardLayout.QueryFragment}
  ${LoginPage.QueryFragment}
`;

export default class LoginRoute extends React.Component {
  render() {
    return (
      <Query query={LoginQuery}>
        {({ loading, error, data }) => (
          <StandardLayout
            data={{ ...data, loading, error }}
            bodyComponent={LoginPage}
          />
        )}
      </Query>
    );
  }
}
