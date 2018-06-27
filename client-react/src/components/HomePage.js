import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import ForumItem from "./ForumItem";

export default class HomePage extends React.Component {
  static QueryFragment = gql`
    fragment HomePage_QueryFragment on Query {
      currentUser {
        nodeId
        id
        isAdmin
        ...ForumItem_CurrentUserFragment
      }
      allForums {
        nodes {
          nodeId
          ...ForumItem_ForumFragment
        }
      }
    }
    ${ForumItem.ForumFragment}
    ${ForumItem.CurrentUserFragment}
  `;

  static propTypes = {
    data: propType(HomePage.QueryFragment),
  };

  render() {
    const { data } = this.props;
    const { loading, error, currentUser, allForums } = data;
    if (loading) {
      return <div className="Main">Loading...</div>;
    }
    if (error) {
      return <div className="Main">Error {error.message}</div>;
    }
    return (
      <div className="Main">
        <h1>Forums</h1>
        {allForums.nodes.length ? (
          allForums.nodes.map(node => (
            <ForumItem
              key={node.nodeId}
              forum={node}
              currentUser={currentUser}
            />
          ))
        ) : (
          <div>
            There are no forums yet!{" "}
            {currentUser.isAdmin
              ? "Create one below..."
              : "Please check back later or contact an admin."}
          </div>
        )}
      </div>
    );
  }
}
