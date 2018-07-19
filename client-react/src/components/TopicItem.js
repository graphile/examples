import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import { Link } from "react-router-dom";
import moment from "moment";

export default class TopicItem extends React.Component {
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

  static propTypes = {
    topic: propType(TopicItem.TopicFragment)
  };

  render() {
    const { topic, forum } = this.props;

    return (
      <tr className="TopicItem">
        <td className="TopicItem-title">
          <Link to={`/forums/${forum.slug}/${topic.id}`}>{topic.title}</Link>
        </td>
        <td className="TopicItem-user">{topic.user.name}</td>
        <td className="TopicItem-replies">{topic.posts.totalCount}</td>
        <td className="TopicItem-date">{moment(topic.updatedAt).calendar()}</td>
      </tr>
    );
  }
}
