import React from "react";
import gql from "graphql-tag";
import { propType } from "graphql-anywhere";
import { Mutation } from "react-apollo";
import _slug from "slug";
import PropTypes from "prop-types";

const autoSlug = str => _slug(str, _slug.defaults.modes["rfc3986"]);

const CreateTopicMutation = gql`
  mutation CreateTopicMutation($title: String!, $body: String, $forumId: Int!) {
    createTopic(
      input: { topic: { title: $title, body: $body, forumId: $forumId } }
    ) {
      topic {
        nodeId
        id
        title
        body
        forumId
      }
    }
  }
`;

export default class CreateNewTopicForm extends React.Component {
  static QueryFragment = gql`
    fragment CreateNewTopicForm_QueryFragment on Query {
      currentUser {
        nodeId
      }
    }
  `;

  static propTypes = {
    data: propType(CreateNewTopicForm.QueryFragment),
    onCreateTopic: PropTypes.func,
  };

  state = {
    slug: null,
    name: "",
    description: "",
  };

  handleChange = key => e => {
    this.setState({ [key]: e.target.value, error: null });
  };

  handleSuccess = ({
    data: {
      createTopic: { forum },
    },
  }) => {
    console.dir(forum);
    this.setState({
      sending: false,
      slug: null,
      name: "",
      description: "",
    });
    if (typeof this.props.onCreateTopic === "function") {
      this.props.onCreateTopic(forum);
    }
  };

  handleError = e => {
    this.setState({ sending: false, error: e });
  };

  slug = () =>
    this.state.slug != null ? this.state.slug : autoSlug(this.state.name);

  render() {
    return (
      <Mutation mutation={CreateTopicMutation}>
        {createNewMutation => (
          <form
            onSubmit={e => {
              e.preventDefault();
              if (this.state.sending) return;
              this.setState({ sending: true });
              createNewMutation({
                variables: {
                  slug: this.slug(),
                  name: this.state.name,
                  description: this.state.description,
                },
              }).then(this.handleSuccess, this.handleError);
            }}
          >
            <table>
              <tbody>
                <tr>
                  <th>Name !!!!!</th>
                  <td>
                    <input
                      type="text"
                      value={this.state.name}
                      onChange={this.handleChange("name")}
                    />
                  </td>
                </tr>
                <tr>
                  <th>Url</th>
                  <td>
                    <input
                      type="text"
                      value={this.slug()}
                      onChange={this.handleChange("slug")}
                    />
                  </td>
                </tr>
                <tr>
                  <th>Description</th>
                  <td>
                    <input
                      type="text"
                      value={this.state.description}
                      onChange={this.handleChange("description")}
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
              Create Topic
            </button>
          </form>
        )}
      </Mutation>
    );
  }
}
