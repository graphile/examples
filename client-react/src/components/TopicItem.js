import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import Topic from "./presentational/Topic";

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

    return <Topic {...topic} slug={forum.slug} />;
  }
}
