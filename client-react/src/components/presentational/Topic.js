import React from "react";
import { Link } from "react-router-dom";
import moment from "moment";

export const Topic = ({ slug, id, title, user, updatedAt, posts }) => (
  <tr className="TopicItem">
    <td className="TopicItem-title">
      <Link to={`/forums/${slug}/${id}`}>{title}</Link>
    </td>
    <td className="TopicItem-user">{user.name}</td>
    <td className="TopicItem-replies">{posts.totalCount}</td>
    <td className="TopicItem-date">{moment(updatedAt).calendar()}</td>
  </tr>
);

export default Topic;
