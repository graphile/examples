import React from 'react';
import { Redirect } from 'react-router-dom';

export default class LoginPage extends React.Component {
  render() {
    const {loading, error, data} = this.props;
    if (loading) {
      return <div>Loading...</div>
    }
    if (error) {
      return <div>Error {error.message}</div>
    }
    if (data.currentUser) {
      return <Redirect to="/" />
    } else {
      return (
        <div>
          <h1>Log in</h1>
          <p>With <a href="/auth/github">GitHub</a></p>
        </div>
      )
    }
  }
}
