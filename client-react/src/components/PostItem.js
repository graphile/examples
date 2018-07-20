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
        name
      }
    }
  `;

  static propTypes = {
    post: propType(PostItem.PostFragment)
  };

  render() {
    const { post } = this.props;
    const { user, createdAt, body } = post;

    return (
      <article className="PostItem">
        <div className="PostItem-meta PostItem-user PostItem-user--with-avatar">
          <img alt="" className="PostItem-avatar" src={user.avatarUrl} />
          {user.name}
        </div>
        <div>
          <time className="PostItem-date">{moment(createdAt).calendar()}</time>
          <p className="PostItem-body">{body}</p>
        </div>
      </article>
    );
  }
}
