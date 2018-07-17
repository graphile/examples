import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import { Link } from "react-router-dom";
import moment from "moment";

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
      body
      user {
        nodeId
        avatarUrl
        name
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
    topic: propType(TopicItem.TopicFragment)
    /*currentUser: propType(ForumItem.CurrentUserFragment),*/
  };

  render() {
    const { topic, forum } = this.props;
    const updatedDate = topic.updatedAt;
    const totalCount = topic.posts.totalCount;

    return (
      <tr className="TopicItem">
        <td className="TopicItem-title">
          <Link to={`/forums/${forum.slug}/${topic.id}`}>{topic.title}</Link>
        </td>
        <td className="TopicItem-user">{topic.user.name}</td>
        <td className="TopicItem-replies">{totalCount}</td>
        <td className="TopicItem-date">{moment(updatedDate).calendar()}</td>
      </tr>
    );
  }
}
