import React from "react";
import gql from "graphql-tag";
import { Query } from "react-apollo";
import StandardLayout from "../layouts/StandardLayout";
import NotFound from "../components/NotFound";

const NotFoundRouteQuery = gql`
  query NotFoundRouteQuery {
    ...StandardLayout_QueryFragment
  }
  ${StandardLayout.QueryFragment},
`;

export default class HomeRoute extends React.Component {
  render() {
    return (
      <Query query={NotFoundRouteQuery}>
        {({ loading, error, data }) => (
          <StandardLayout
            data={{ ...data, loading, error }}
            bodyComponent={NotFound}
          />
        )}
      </Query>
    );
  }
}
