import React from "react";
import gql from "graphql-tag";
import { Query } from "react-apollo";
import StandardLayout from "../layouts/StandardLayout";
import TopicPage from "../components/TopicPage";
import PropTypes from "prop-types";

const TopicQuery = gql`
  query TopicQuery($topic: Int!) {
    ...StandardLayout_QueryFragment
    ...TopicPage_QueryFragment
  }
  ${StandardLayout.QueryFragment}
  ${TopicPage.QueryFragment}
`;

export default class TopicRoute extends React.Component {
  static propTypes = {
    match: PropTypes.shape({
      params: PropTypes.shape({
        id: PropTypes.node,
      }).isRequired,
    }).isRequired,
  };

  render() {
    console.log(this.props);
    const {
      params: { topic },
    } = this.props.match;
    return (
      <Query query={TopicQuery} variables={{ topic }}>
        {({ loading, error, refetch, data }) => (
          <StandardLayout
            data={{
              ...data,
              loading,
              error,
              refetch,
            }}
            bodyComponent={TopicPage}
          />
        )}
      </Query>
    );
  }
}
