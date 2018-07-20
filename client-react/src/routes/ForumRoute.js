import React from "react";
import gql from "graphql-tag";
import { Query } from "react-apollo";
import StandardLayout from "../layouts/StandardLayout";
import ForumPage from "../components/ForumPage";
import PropTypes from "prop-types";

const ForumQuery = gql`
  query ForumQuery($slug: String!) {
    ...StandardLayout_QueryFragment
    ...ForumPage_QueryFragment
  }
  ${StandardLayout.QueryFragment}
  ${ForumPage.QueryFragment}
`;

export default class ForumRoute extends React.Component {
  static propTypes = {
    match: PropTypes.shape({
      params: PropTypes.shape({
        id: PropTypes.node,
      }).isRequired,
    }).isRequired,
  };
  render() {
    const {
      params: { slug },
    } = this.props.match;
    return (
      <Query query={ForumQuery} variables={{ slug }}>
        {({ loading, error, refetch, data }) => (
          <StandardLayout
            data={{
              ...data,
              loading,
              error,
              refetch,
            }}
            bodyComponent={ForumPage}
          />
        )}
      </Query>
    );
  }
}
