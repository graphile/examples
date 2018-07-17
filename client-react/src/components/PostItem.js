import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import Reply from "./presentational/Reply";

export default class PostItem extends React.Component {
  static PostFragment = gql`
    fragment PostItem_PostFragment on Post {
      nodeId
      id
      body
      createdAt
      user {
        id
        avatarUrl
        name
      }
    }
  `;

  static propTypes = {
    post: propType(PostItem.PostFragment)
  };

  render() {
    const { post } = this.props;

    return <Reply {...post} />;
  }
}
