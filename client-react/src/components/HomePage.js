import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import { Link } from "react-router-dom";
import ForumItem from "./ForumItem";
import Main from "./Main";
import CreateNewForumForm from "./CreateNewForumForm";

export default class HomePage extends React.Component {
  static QueryFragment = gql`
    fragment HomePage_QueryFragment on Query {
      ...CreateNewForumForm_QueryFragment
      currentUser {
        nodeId
        id
        isAdmin
        ...ForumItem_CurrentUserFragment
      }
      allForums(first: 50) {
        nodes {
          nodeId
          ...ForumItem_ForumFragment
        }
      }
    }
    ${ForumItem.ForumFragment}
    ${ForumItem.CurrentUserFragment}
    ${CreateNewForumForm.QueryFragment}
  `;

  static propTypes = {
    data: propType(HomePage.QueryFragment),
  };

  render() {
    const { data } = this.props;
    const { loading, error, currentUser, allForums } = data;
    if (loading) {
      return <Main>Loading...</Main>;
    }
    if (error) {
      return <Main>Error {error.message}</Main>;
    }
    return (
      <Main>
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
            {currentUser ? (
              currentUser.isAdmin ? (
                "Create one below..."
              ) : (
                "Please check back later or contact an admin."
              )
            ) : (
              <span>
                Perhaps you need to <Link to="/login">log in</Link>?
              </span>
            )}
          </div>
        )}
        {currentUser && currentUser.isAdmin ? (
          <div>
            <h2>Create new forum</h2>
            <p>Hello administrator! Would you like to create a new forum?</p>
            <CreateNewForumForm
              data={data}
              onCreateForum={forum => {
                // TODO: alter the cache
                data.refetch();
              }}
            />
          </div>
        ) : null}
      </Main>
    );
  }
}
