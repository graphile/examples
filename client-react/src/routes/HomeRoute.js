import React from "react";
import gql from "graphql-tag";
import { Query } from "react-apollo";
import StandardLayout from "../layouts/StandardLayout";
import HomePage from "../components/HomePage";

const HomeRouteQuery = gql`
  query HomeRouteQuery {
    ...StandardLayout_QueryFragment
    ...HomePage_QueryFragment
  }
  ${StandardLayout.QueryFragment}
  ${HomePage.QueryFragment}
`;

export default class HomeRoute extends React.Component {
  render() {
    return (
      <Query query={HomeRouteQuery}>
        {({ loading, error, data }) => (
          <StandardLayout
            data={
              {
                ...data,
                loading,
                error,
              } /* this mess is to make it compatible with graphql-anywhere's propType */
            }
            bodyComponent={HomePage}
          />
        )}
      </Query>
    );
  }
}
