import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import { Link } from "react-router-dom";
import ForumItem from "./ForumItem";
import TopicItem from "./TopicItem";
import Main from "./Main";
import NotFound from "./NotFound";
import CreateNewForumForm from "./CreateNewForumForm";

export default class ForumPage extends React.Component {
  static QueryFragment = gql`
    fragment ForumPage_QueryFragment on Query {
      ...CreateNewForumForm_QueryFragment
      currentUser {
        nodeId
        id
        isAdmin
        ...ForumItem_CurrentUserFragment
      }
      forum: forumBySlug(slug: $slug) {
        nodeId
        name
        topics {
          nodes {
            ...TopicItem_TopicFragment
          }
        }
        ...ForumItem_ForumFragment
      }
    }
    ${TopicItem.TopicFragment}
    ${ForumItem.ForumFragment}
    ${ForumItem.CurrentUserFragment}
    ${CreateNewForumForm.QueryFragment}
  `;

  static propTypes = {
    data: propType(ForumPage.QueryFragment),
  };

  render() {
    const { data } = this.props;
    const { loading, error, currentUser, forum } = data;
    if (loading) {
      return <Main>Loading...</Main>;
    }
    if (error) {
      return <Main>Error {error.message}</Main>;
    }
    if (!forum) {
      return <NotFound />;
    }
    return (
      <Main>
        <h1>{forum.name}</h1>
        <div>
          {forum.topics.nodes.length ? (
            forum.topics.nodes.map(node => (
              <TopicItem
                key={node.nodeId}
                forum={node}
                currentUser={currentUser}
              />
            ))
          ) : (
            <div>
              There are no topics yet!{" "}
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
        </div>
        {currentUser && currentUser.isAdmin ? (
          <div>
            <h2>Create new forum</h2>
            <p>Hello administrator! Would you like to create a new forum?</p>
            <CreateNewForumForm
              data={data}
              onCreateForum={_forum => {
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
