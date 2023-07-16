FROM alpine

LABEL "name"="SUSE OBS API Fetch"
LABEL "description"="GitHub Action to get SUSE OBS API responses and save them to repository."
LABEL "maintainer"="iHub TO <mail@ihub.to>"
LABEL "repository"="https://github.com/ghastore/obs-api"
LABEL "homepage"="https://github.com/ghastore"

COPY *.sh /
RUN apk add --no-cache bash curl git git-lfs jq yq

ENTRYPOINT ["/entrypoint.sh"]
