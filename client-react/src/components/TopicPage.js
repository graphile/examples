import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import { Link } from "react-router-dom";
import TopicItem from "./TopicItem";
import PostItem from "./PostItem";
import Main from "./Main";
import NotFound from "./NotFound";
import CreateNewPostForm from "./CreateNewPostForm";
import ForumItem from "./ForumItem";

export default class TopicPage extends React.Component {
  static QueryFragment = gql`
    fragment TopicPage_QueryFragment on Query {
      ...CreateNewPostForm_QueryFragment
      currentUser {
        nodeId
        id
        isAdmin
        ...ForumItem_CurrentUserFragment
      }
      topic: topicById(id: $topic) {
        ...TopicItem_TopicFragment
        posts {
          nodes {
            ...PostItem_PostFragment
          }
        }
      }
    }
    ${TopicItem.TopicFragment}
    ${PostItem.PostFragment}
    ${ForumItem.CurrentUserFragment}
    ${CreateNewPostForm.QueryFragment}
  `;

  static propTypes = {
    data: propType(TopicPage.QueryFragment)
  };

  render() {
    const { data } = this.props;
    const { loading, error, currentUser, topic } = data;
    if (loading) {
      return <Main>Loading...</Main>;
    }
    if (error) {
      return <Main>Error {error.message}</Main>;
    }
    if (!topic) {
      return <NotFound />;
    }
    return (
      <Main>
        <h1 className="Topic-header">{topic.title}</h1>
        <div className="Topic-description">
          Welcome to {topic.title}! {topic.description}
        </div>
        <section className="Posts-container">
          {topic.posts.nodes.length ? (
            topic.posts.nodes.map(node => (
              <PostItem
                key={node.nodeId}
                post={node}
                currentUser={currentUser}
              />
            ))
          ) : (
            <div>
              There are no posts yet!{" "}
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
        </section>
        {currentUser ? (
          <div>
            <h2>Post to this topic</h2>
            <CreateNewPostForm
              data={data}
              onCreatePost={post => {
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
