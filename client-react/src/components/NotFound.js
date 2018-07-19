import React from "react";
import Main from "./Main";
import { Link } from "react-router-dom";

export default class NotFound extends React.Component {
  render() {
    return (
      <Main>
        <h1>Page not found!</h1>
        <p>
          <Link to="/">Return home</Link>
        </p>
      </Main>
    );
  }
}
