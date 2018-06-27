import { ApolloClient } from "apollo-client";
import { HttpLink } from "apollo-link-http";
import { InMemoryCache } from "apollo-cache-inmemory";

export default function makeClient() {
  return new ApolloClient({
    link: new HttpLink({
      uri: "/graphql",
      credentials: "same-origin",
    }),
    cache: new InMemoryCache({
      dataIdFromObject: object => object.nodeId,
    }),
  });
}
