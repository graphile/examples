import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import { Link } from "react-router-dom";
import moment from "moment";
import ForumItem from "./ForumItem";
import logo from "../logo.svg";

export default class TopicItem extends React.Component {
  static TopicFragment = gql`
    fragment TopicItem_TopicFragment on Topic {
      nodeId
      id
      title
      body
      user: author {
        nodeId
        avatarUrl
        name
      }
      posts {
          totalCount
          nodes {
              author {
                  avatarUrl
              }
          }
      }
      updatedAt
    }
  `;

  static propTypes = {
    topic: propType(TopicItem.TopicFragment),
    forum: propType(ForumItem.TopicFragment),
  };

  render() {
      const { topic, forum } = this.props;
      const avatarList = topic.posts.nodes.slice(-4);


      return (
          <tr className="topic-item">
              <td className="topic-item__title">
                  <Link className="topic-item__link" to={`/forums/${forum.slug}/${topic.id}`}>{topic.title}</Link>
              </td>
              <td className="topic-item__profiles">
                  {avatarList.map(({author}, index) => (
                      <div className="topic-item__profile-container">
                          <img
                              className="topic-item__profile"
                              key={index}
                              src={author.avatarUrl || logo}
                              alt=""
                          />
                      </div>
                  ))}
              </td>
              <td className="topic-item__replies">{topic.posts.totalCount}</td>
              <td className="topic-item__date">{moment(topic.updatedAt).fromNow(true)}</td>
          </tr>
      );
  }
}
