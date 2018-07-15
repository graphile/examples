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
    const updatedDate = post.updatedAt;

    return (
      <article className="PostItem">
        <header>
          <h2 className="PostItem-user">{post.user.username}</h2>
          <time className="PostItem-date">
            {moment(updatedDate).calendar()}
          </time>
        </header>
        <p className="PostItem-body">{post.body}</p>
      </article>
    );
  }
}
