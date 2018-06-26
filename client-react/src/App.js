import React, { Component } from 'react';
import gql from 'graphql-tag';
import { Query } from 'react-apollo';
import { Switch, Route } from 'react-router-dom';
import HomeRoute from './routes/HomeRoute';
import NotFoundRoute from './routes/NotFoundRoute';

import './App.css';

const CURRENT_USER = gql`
  query CurrentUser {
    currentUser {
      nodeId
      id
      isAdmin
      name
    }
  }
`;

class App extends Component {
  render() {
    return (
      <div className="App">
        <Switch>
          <Route path="/" exact component={HomeRoute} />
          <Route component={NotFoundRoute} />
        </Switch>
      </div>
    );
  }
}

export default App;
