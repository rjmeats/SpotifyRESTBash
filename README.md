# Spotify REST API from Bash shell
Some examples of invoking the [Spotify REST API](https://developer.spotify.com/documentation/web-api/) from the Bash shell, using curl and [jq](https://stedolan.github.io/jq/).

Spotify REST API endpoints demonstrated include:

* albums
* artists
* tracks
* browse

JSON output returned by the API is held under the *output* folder. Additional files included in the output folder record the headers returned and the URL invoked.

Put a valid Spotify access token in the *token.txt* file before running.