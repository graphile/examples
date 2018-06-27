import React from "react";
import PropTypes from "prop-types";

const Main = ({ children }) => <div className="Main">{children}</div>;
Main.propTypes = {
  children: PropTypes.node,
};
export default Main;
