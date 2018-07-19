import React from "react";
import moment from "moment";

export const Reply = ({ user, createdAt, body }) => (
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

export default Reply;
