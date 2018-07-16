import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import moment from "moment";

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
        username
      }
    }
  `;

  static propTypes = {
    post: propType(PostItem.PostFragment)
  };

  render() {
    const { post } = this.props;
    const createdDate = post.createdAt;

    return (
      <article className="PostItem">
        <div className="PostItem-meta">
          <div className="PostItem-user">{post.user.username}</div>
          <time className="PostItem-date">
            {moment(createdDate).calendar()}
          </time>
        </div>
        <p className="PostItem-body">{post.body}</p>
      </article>
    );
  }
}
