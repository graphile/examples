import React from 'react';
import gql from 'graphql-tag';
import { Query } from 'react-apollo';
import StandardLayout from '../layouts/StandardLayout';
import LoginPage from '../components/LoginPage';

const LoginQuery = gql`
  query LoginQuery {
    ...StandardLayout_QueryFragment
  }
  ${StandardLayout.QueryFragment},
`

export default class LoginRoute extends React.Component {
  render() {
    return (
      <Query query={LoginQuery}>
        {(graphql) => <StandardLayout graphql={graphql} bodyComponent={LoginPage} />}
      </Query>
    );
  }
}

