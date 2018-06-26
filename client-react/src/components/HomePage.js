import React from 'react';
import { Link } from 'react-router-dom';

export default class HomePage extends React.Component {
  render() {
    const {loading, error, data} = this.props;
    if (loading) {
      return <div>Loading...</div>
    }
    if (error) {
      return <div>Error {error.message}</div>
    }
    if (data.currentUser) {
      return <div>Logged in as user {data.currentUser.id}</div>
    } else {
      return <div>To log in, <Link to="/login">click here</Link></div>
    }
  }
}
