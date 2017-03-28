#!/usr/bin/env bash

NAME="Deploy"
DESCRIPTION="Deploys by running a git deploy and an app build."
VERSION="0.2.2"

set -o errexit
set -o pipefail

# ----------
# Initialization
# ----------

# Script Defaults
GIT_BRANCH=${DEPLOY_GIT_BRANCH:-master}
GIT_TAG=${DEPLOY_GIT_TAG}
GIT_WORK_TREE=${DEPLOY_GIT_WORK_TREE:-}
GIT_DIR=${DEPLOY_GIT_DIR:-}
DEPLOY_ALLOWED_BRANCHES=("master" "develop")

# Script Variables
CURRENT_DIR=`pwd`
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
me=$(basename "$0")
GIT_ARGS=()

# ----------
# Functions
# ----------

function parseArgs()
{
  while [[ $# -gt 0 ]]; do
    opt="$1"
    shift

    case "$opt" in

      -h|\?|--help)
        showHelp
        exit 0
        ;;

      -b|--git-branch)
        GIT_BRANCH="$1"
        shift
        ;;

      -t|--git-tag)
        GIT_TAG="$1"
        shift
        ;;

      -w|--git-work-tree)
        GIT_WORK_TREE="$1"
        shift
        ;;

      -d|--git-dir)
        GIT_DIR="$1"
        shift
        ;;

      --bare)
        BARE=true
        ;;

      --dry-run)
        DRY_RUN=true
        ;;

      *)
        errorExit 1 "illegal option $opt"
        showHelp
        ;;

    esac
  done
}

function showHelp()
{
  cat << EOF
options:
  -h, --help                        Show this help.
  -b, --git-branch
  -t, --git-tag
  -w, --git-work-tree
  -d, --git-dir
  --bare
  --dry-run
EOF
}

function defineVariables()
{

  # Add GIT_WORK_TREE to GIT_ARGS
  if [ -z "${GIT_WORK_TREE}" ]; then
    GIT_WORK_TREE=${CURRENT_DIR}
  fi
  GIT_ARGS+=("--work-tree=${GIT_WORK_TREE}")

  # Add GIT_DIR to GIT_ARGS
  if [ -z "${GIT_DIR}" ]; then
    GIT_DIR=${CURRENT_DIR}
  fi
  GIT_ARGS+=("--git-dir=${GIT_DIR}")
}

function showOptions()
{
  # Tell user the options they've selected
  echo
  echo "---------------------"
  echo "$me: Options"
  echo "---------------------"

  # Echo if using GIT_TAG or GIT_BRANCH
  if ! [ -z "${GIT_TAG}" ]; then
    echo "Tag: ${GIT_TAG}"
  else
    echo "Branch: ${GIT_BRANCH}"
  fi

  # Echo Git Work Tree
  echo "Git Work Tree: ${GIT_WORK_TREE}"

  # Echo Git Directory
  echo "Git Directory: ${GIT_DIR}"

  # Dry Run
  if [ -n "${DRY_RUN}" ]; then
    echo "Dry Run: true"
  fi
}

function processManagement()
{
  echo
  echo "---------------------"
  echo "$me: Process Management"
  echo "---------------------"

  # Create process daemon folder
  mkdir -p /var/run/deploy

  if [ -f /var/run/deploy/deploy.pid ]; then
      echo "Process already running."
      kill -9 `cat /var/run/deploy/deploy.pid`
      rm -f /var/run/deploy/deploy.pid
  fi
  echo `pidof $$` > /var/run/deploy/deploy.pid
}

function gitDeploy()
{
  echo
  echo "---------------------"
  echo "$me: Git Deploy"
  echo "---------------------"

  # Make sure directory exists. Maybe its deployed for the first time.
  mkdir -p "${GIT_WORK_TREE}"

  # Put us in the right directory
  cd "${GIT_WORK_TREE}"

  if [ $(contains "${DEPLOY_ALLOWED_BRANCHES[@]}" "${GIT_BRANCH}") != "y" ]; then
      echo
      echo "Error: Branch ${GIT_BRANCH} is not allowed to deploy"
      finished
      exit 1
  fi

  # Pre Deploy
  if ! [ -z "${PRE_DEPLOY}" ]; then
    gitDeployPre
  fi

  # Determine type of deploy
  if ! [ -z "${BARE}" ]; then
    gitDeployBare
  else
    gitDeployFull
  fi

  # Post Deploy
  if ! [ -z "${POST_DEPLOY}" ]; then
    gitDeployPost
  fi
}

function gitDeployPre()
{
  echo
  echo "Git Deploy: Pre Commands"
  echo "CMD: '${PRE_DEPLOY}'"

  if [ ! -n "${DRY_RUN}" ]; then
    eval $PRE_DEPLOY || exit 1
  fi
}

function gitDeployPost()
{
  echo
  echo "Git Deploy: Post Commands"
  echo "CMD: '${POST_DEPLOY}'"

  if [ ! -n "${DRY_RUN}" ]; then
    eval $POST_DEPLOY || exit 1
  fi
}

function gitDeployBare()
{

  echo
  echo "Git Deploy: Checkout"
  echo "CMD: 'git ${GIT_ARGS[@]} checkout -f ${GIT_BRANCH}'"

  if [ ! -n "${DRY_RUN}" ]; then
    git ${GIT_ARGS[@]} checkout -f ${GIT_BRANCH}
  fi

}

function gitDeployFull()
{

  # GIT_TAG is not empty
  if ! [ -z "${GIT_TAG}" ]; then

    # Git Fetch
    echo
    echo "Git Deploy: Fetch"
    echo "CMD: 'git ${GIT_ARGS[@]} fetch --depth 1 origin \"tags/${GIT_TAG}\"'"

    if [ ! -n "${DRY_RUN}" ]; then
      git ${GIT_ARGS[@]} fetch --depth 1 origin "tags/${GIT_TAG}"
    fi

    # Git Checkout
    echo
    echo "Git Deploy: Checkout"
    echo "CMD: 'git ${GIT_ARGS[@]} checkout --force \"tags/${GIT_TAG}\"'"

    if [ ! -n "${DRY_RUN}" ]; then
      git ${GIT_ARGS[@]} checkout --force "tags/${GIT_TAG}"
    fi

  else

    # Git Fetch
    echo
    echo "Git Deploy: Fetch"
    echo "CMD: 'git ${GIT_ARGS[@]} fetch origin ${GIT_BRANCH}'"

    if [ ! -n "${DRY_RUN}" ]; then
      git ${GIT_ARGS[@]} fetch origin ${GIT_BRANCH}
    fi

    # Git Checkout
    echo
    echo "Git Deploy: Checkout"
    echo "CMD: 'git ${GIT_ARGS[@]} checkout --force \"origin/${GIT_BRANCH}\"'"

    if [ ! -n "${DRY_RUN}" ]; then
      git ${GIT_ARGS[@]} checkout --force "origin/${GIT_BRANCH}"
    fi

  fi
}

function setup()
{

  if [[ -n "$CURRENT_DIR" && -e "$CURRENT_DIR/.deploy" ]]; then
    . "$CURRENT_DIR/.deploy"
  fi

  if [[ -n "$CURRENT_DIR" && -e "$CURRENT_DIR/.env" ]]; then
    . "$CURRENT_DIR/.env"
  fi
}

function start()
{
  echo
  echo "--------------------------------------------------"
  echo "$me: ${NAME} v${VERSION} - ${DESCRIPTION}"
  echo "$me: STARTED `date`"
  echo "--------------------------------------------------"
}

function finished()
{
  cd "${CURRENT_DIR}"

  echo
  echo "--------------------------------------------------"
  echo "$me: FINISHED `date`"
  echo "--------------------------------------------------"
  echo

  exit
}

function errorExit()
{
  exitCode=$1
  shift
  echo "$me: $@" > /dev/null >&2
  exit $exitCode
}

function contains() {
  local n=$#
  local value=${!n}
  for ((i=1;i < $#;i++)) {
      if [ "${!i}" == "${value}" ]; then
          echo "y"
          return 0
      fi
  }
  echo "n"
  return 1
}


# ----------
# Main
# ----------
parseArgs "$@"
start
setup
defineVariables
showOptions
processManagement
gitDeploy
finished
