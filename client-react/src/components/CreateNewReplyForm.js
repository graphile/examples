import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import { Mutation } from "react-apollo";
import PropTypes from "prop-types";

const CreatePostMutation = gql`
  mutation CreatePostMutation($body: String!, $topicId: Int!) {
    createPost(input: { post: { body: $body, topicId: $topicId } }) {
      post {
        nodeId
        id
        body
        topicId
      }
    }
  }
`;

export default class CreateNewReplyForm extends React.Component {
  static QueryFragment = gql`
    fragment CreateNewReplyForm_QueryFragment on Query {
      currentUser {
        nodeId
      }
    }
  `;

  static propTypes = {
    data: propType(CreateNewReplyForm.QueryFragment),
    onCreatePost: PropTypes.func
  };

  state = {
    body: ""
  };

  handleChange = key => e => {
    this.setState({ [key]: e.target.value, error: null });
  };

  handleSuccess = ({
    data: {
      createPost: { forum }
    }
  }) => {
    this.setState({
      sending: false,
      body: ""
    });
    if (typeof this.props.onCreatePost === "function") {
      this.props.onCreatePost(forum);
    }
  };

  handleError = e => {
    this.setState({ sending: false, error: e });
  };

  render() {
    const { data } = this.props;
    const { topic } = data;
    return (
      <Mutation mutation={CreatePostMutation}>
        {createNewMutation => (
          <form
            onSubmit={e => {
              e.preventDefault();
              if (this.state.sending) return;
              this.setState({ sending: true });
              createNewMutation({
                variables: {
                  body: this.state.body,
                  topicId: topic.id
                }
              }).then(this.handleSuccess, this.handleError);
            }}
          >
            <table>
              <tbody>
                <tr>
                  <th>Reply</th>
                  <td>
                    <input
                      type="text"
                      value={this.state.body}
                      onChange={this.handleChange("body")}
                    />
                  </td>
                </tr>
              </tbody>
            </table>
            {this.state.error ? (
              <p className="error">
                An error occurred! {this.state.error.message}
              </p>
            ) : null}
            <button disabled={this.state.sending} type="submit">
              Submit
            </button>
          </form>
        )}
      </Mutation>
    );
  }
}
