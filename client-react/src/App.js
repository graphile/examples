import React, { Component } from "react";
import { Switch, Route } from "react-router-dom";
import HomeRoute from "./routes/HomeRoute";
import NotFoundRoute from "./routes/NotFoundRoute";
import LoginRoute from "./routes/LoginRoute";

class App extends Component {
  render() {
    return (
      <div className="App">
        <Switch>
          <Route path="/" exact component={HomeRoute} />
          <Route path="/login" exact component={LoginRoute} />
          <Route component={NotFoundRoute} />
        </Switch>
      </div>
    );
  }
}

export default App;
