import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import { Link } from "react-router-dom";

export default class TopicItem extends React.Component {
  /*static ForumFragment = gql`
    fragment ForumItem_ForumFragment on Forum {
      nodeId
      id
      name
      description
      slug
    }
  `;*/

  static TopicFragment = gql`
    fragment TopicItem_TopicFragment on Topic {
      nodeId
      id
      title
      user {
        nodeId
        avatarUrl
        username
      }
      posts {
        totalCount
      }
      updatedAt
    }
  `;

  /*static CurrentUserFragment = gql`
    fragment ForumItem_CurrentUserFragment on User {
      nodeId
      isAdmin
    }`;*/

  static propTypes = {
    topic: propType(TopicItem.TopicFragment),
    /*currentUser: propType(ForumItem.CurrentUserFragment),*/
  };

  render() {
    const { topic } = this.props;
    const updatedDate = topic.updatedAt;
    const totalCount = topic.posts.totalCount;

    return (
      <tr className="TopicItem">
        <td className="TopicItem-title">
          <Link to={`/forums/topic/1`}>{topic.title}</Link>
        </td>
        <td className="TopicItem-user">{topic.user.username}</td>
        <td className="TopicItem-replies">{totalCount}</td>
        <td className="TopicItem-date">{updatedDate}</td>
      </tr>
    );
  }
}
