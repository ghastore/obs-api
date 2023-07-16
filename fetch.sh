#!/bin/bash -e

# -------------------------------------------------------------------------------------------------------------------- #
# CONFIGURATION.
# -------------------------------------------------------------------------------------------------------------------- #

# Action.
GIT_REPO="${1}"
GIT_USER="${2}"
GIT_EMAIL="${3}"
GIT_TOKEN="${4}"
API_URL="${5}"
API_DIR="${6}"
API_PROJECT="${7}"
API_USER="${8}"
API_PASSWORD="${9}"
BOT_INFO="${10}"

# Vars.
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36 (${BOT_INFO})"

# Apps.
curl="$( command -v curl )"
date="$( command -v date )"
git="$( command -v git )"
jq="$( command -v jq )"
mkdir="$( command -v mkdir )"
yq="$( command -v yq )"

# Dirs.
d_src="/root/git/repo"
d_obs_project="${API_DIR}/projects/${API_PROJECT//:/\/}"

# Git.
${git} config --global user.name "${GIT_USER}"
${git} config --global user.email "${GIT_EMAIL}"
${git} config --global init.defaultBranch 'main'

# -------------------------------------------------------------------------------------------------------------------- #
# INITIALIZATION.
# -------------------------------------------------------------------------------------------------------------------- #

init() {
  ts="$( _timestamp )"
  clone
  obs_project \
    && obs_packages \
    && obs_build \
    && obs_user
  push
}

# -------------------------------------------------------------------------------------------------------------------- #
# GIT: CLONE REPOSITORY.
# -------------------------------------------------------------------------------------------------------------------- #

clone() {
  echo "--- [GIT] CLONE: ${GIT_REPO#https://}"

  local src="https://${GIT_USER}:${GIT_TOKEN}@${GIT_REPO#https://}"
  ${git} clone "${src}" "${d_src}"

  echo "--- [GIT] LIST: '${d_src}'"
  ls -1 "${d_src}"
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: PROJECT.
# -------------------------------------------------------------------------------------------------------------------- #

obs_project() {
  echo "--- [SUSE OBS] ${API_PROJECT^^} / INFO"
  _pushd "${d_src}" || exit 1

  local dir="${d_obs_project}"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local api="${API_URL}/source/${API_PROJECT}/_meta"
  echo "Get '${api}'..." && _json "${api}" > "${dir}/info.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: PACKAGES.
# -------------------------------------------------------------------------------------------------------------------- #

obs_packages() {
  echo "--- [SUSE OBS] ${API_PROJECT^^} / PACKAGES"
  _pushd "${d_src}" || exit 1

  local dir="${d_obs_project}/packages"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local api="${API_URL}/source/${API_PROJECT}"

  local pkgs
  readarray -t pkgs < <( _json "${api}" ".[].entry | .[]._name" )

  for pkg in "${pkgs[@]}"; do
    local api_pkg="${api}/${pkg}/_meta"
    local dir_pkg="${dir}/${pkg}"
    [[ ! -d "${dir_pkg}" ]] && _mkdir "${dir_pkg}"
    echo "Get '${api_pkg}'..." && _json "${api_pkg}" "." > "${dir_pkg}/info.json"
  done

  ${jq} -nc '$ARGS.positional' --args "${pkgs[@]}" > "${dir%/*}/packages.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: BUILD RESULT.
# -------------------------------------------------------------------------------------------------------------------- #

obs_build() {
  echo "--- [SUSE OBS] ${API_PROJECT^^} / BUILD RESULT"
  _pushd "${d_src}" || exit 1

  local dir="${d_obs_project}"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local api="${API_URL}/build/${API_PROJECT}/_result"
  echo "Get '${api}'..." && _json "${api}" > "${dir}/build.result.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: USER.
# -------------------------------------------------------------------------------------------------------------------- #

obs_user() {
  if [[ "${API_PROJECT}" =~ 'home:' ]]; then
    local user
    user=$( echo "${API_PROJECT}" | awk -F ':' '{ print $2 }' )

    echo "--- [SUSE OBS] USER: ${user^^}"
    _pushd "${d_src}" || exit 1

    local dir="${API_DIR}/users/${user}"
    [[ ! -d "${dir}" ]] && _mkdir "${dir}"

    local api="${API_URL}/person/${user}"
    echo "Get '${api}'..." && _json "${api}" > "${dir}/info.json"

    _popd || exit 1
  fi
}

# -------------------------------------------------------------------------------------------------------------------- #
# GIT: PUSH API TO API STORE REPOSITORY.
# -------------------------------------------------------------------------------------------------------------------- #

push() {
  echo "--- [GIT] PUSH: '${d_src}' -> '${GIT_REPO#https://}'"
  _pushd "${d_src}" || exit 1

  # Commit build files & push.
  echo "Commit build files & push..."
  ${git} add . \
    && ${git} commit -a -m "SUSE OBS API: ${ts}" \
    && ${git} push

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------< COMMON FUNCTIONS >------------------------------------------------ #
# -------------------------------------------------------------------------------------------------------------------- #

# Pushd.
_pushd() {
  command pushd "$@" > /dev/null || exit 1
}

# Popd.
_popd() {
  command popd > /dev/null || exit 1
}

# Timestamp.
_timestamp() {
  ${date} -u '+%Y-%m-%d %T'
}

# Make directory.
_mkdir() {
  ${mkdir} -p "${1}"
}

# Get XML and convert to JSON.
_json() {
  ${curl} -X GET \
    -u "${API_USER}:${API_PASSWORD}" \
    -A "${USER_AGENT}" -fsSL "${1}" \
    | ${yq} --xml-attribute-prefix='_' -p=xml -o=json \
    | ${jq} -rc "${2}"
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

init "$@"; exit 0
