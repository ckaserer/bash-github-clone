#!/bin/bash

####################### 
# READ ONLY VARIABLES #
#######################

readonly PROG_NAME=$(basename "$0")

#################### 
# GLOBAL VARIABLES #
####################

FLAG_DRYRUN=false

#######################
# UNIVERSAL FUNCTIONS #
#######################

# execute $COMMAND [$ALT_TEXT] [$FLAG_DRYRUN=false] [$FLAG_QUIET=false]
# if command and FLAG_DRYRUN=true are set the command will be execuded
# if command and FLAG_DRYRUN=false (or no 3rd argument is provided) 
# if FLAG_QUIET=true are the command will not be printed to stdout
# if FLAG_QUIET=false (or no 4rd argument is provided) print command prefixed by "# "
# if an ALT_TEXT is provided it will print the alt text instead of the command
# this can be used to mask sensitiv information
# the function will only print the command the command to stdout
function execute () {
  local exec_command=$1
  local alt_text=${2:-${1}}
  local flag_dryrun=${3:-${FLAG_DRYRUN:-false}}
  local flag_quiet=${4:-${FLAG_QUIET:-false}}

  if [[ "${flag_dryrun}" == false ]]; then
    if [[ "${flag_quiet}" == false ]]; then
      echo "${alt_text}" | awk '{$1=$1;print}' | sed 's/^/# /'
    fi
    eval "${exec_command}"
  else
    echo "${exec_command}" | awk '{$1=$1;print}'
  fi
}
# readonly definition of a function throws an error if another function 
# with the same name is defined a second time
readonly -f execute || return 1

# print_error $TEXT
# the function will only print TEXT to stderr
function print_error () { 
  >&2 echo "ERROR: $*"
}
readonly -f print_error || return 1

# print_info $TEXT [$FLAG_DRYRUN=false]
# if TEXT and FLAG_DRYRUN=true are set the command will not be execuded.
# this is useful when the info TEXT is based on other sections in the 
# script which are not executed in a dryrun.
# if TEXT and FLAG_DRYRUN=false (or no 3rd argument is provided).
# this can be used to print additional information
# the function will only print TEXT to stdout
function print_info () {
  local text=${1}
  local flag_dryrun=${2:-${FLAG_DRYRUN:-false}}
  
  if [[ "${flag_dryrun}" == false ]]; then
    echo "INFO: ${text}"
  fi
}
readonly -f print_info || return 1

##########
# SCRIPT #
##########

# print usage message
usage_message () {
  echo """
  ${PROG_NAME} is designed to clone github repositories by querying the github api to gather repo URLs.
  
  Usage:
    ${PROG_NAME} <command> [OPT ..]
      
      Examples:
      # clone all public repositories owned by the user ckaserer
      ${PROG_NAME} public --type users --name ckaserer

      # clone all repositories to which the github token has access to
      ${PROG_NAME} authenticated --ghtoken <GH_TOKEN>

      # clone all repositories owned by the user
      ${PROG_NAME} authenticated --ghtoken <GH_TOKEN> --affiliation owner
      
      # clone all my ansible related repos
      ${PROG_NAME} authenticated --ghtoken <GH_TOKEN> --affiliation owner --filter ansible-role

      Available Commands:
        public                  ... clone publicly available repositories using https
          -n | --name)          ... specify the name of the github entity. e.g. your username or orgname
          -t | --type)          ... specify the type of the github entity. Either 'users' or 'orgs'
      
        authenticated           ... clone repositories using ssh. ssh-key required!
          -g | --ghtoken)       ... github access token used to list repos (incl. private and orgs). 

          optional:
            -a | --affiliation) ... clone only repos matching the specified affiliation
                                    available affiliations: owner / colaborator / oranization_member
                                    if no affiliation is specified, all repos will be cloned

      Additional Options:
        -f | --filter)          ... filter repos by string
        
        -d | --dryrun)          ... dryrun
        -h | --help)            ... help"""
}
readonly -f usage_message || return 1

main () {
  # INITIAL VALUES
  local command=${1}            # used to identified the command. values are either 'public' or 'authenticated'
  local github_affiliation=""   # filter repos for affiliation. e.g. clone only owned repos. used by command 'authenticated'
  local github_api_url=""       # different api url based on the command used
  local github_api_response=""  # string containing the json response from the github api
  local github_name=""          # name of the github user or org to clone from
  local github_type=""          # used to generate the api url. 'users' or 'orgs' are supported
  local github_token=""         # used to list private and org repos when using the 'all' command
  local opts=""                 # used to collect options passed to the script
  local page=1                  # used to iterate over multiple pages in the api request. We start with the first page
  local repo_counter=0          # used to check if the requested page in the api response contains new repos
  local repos=()                # array of repositories to clone. Populated by querying the github api
  
  # GETOPT
  # Parse all options except the first one
  # The first option indicates the command and is not a valid option for getopt
  if ! opts=$(getopt -o a:df:g:hn:t: --long affiliation:,dryrun,filter:,ghtoken:,help,name:,type: -- "${@:1}"); then
    print_error "failed to fetch options via getopt" 
    return 1
  fi
  eval set -- "${opts}"
  while true ; do
    case "${1}" in
      -a | --affiliation) 
        github_affiliation=${2}
        shift 2
        ;;
      -d | --dryrun) 
        FLAG_DRYRUN=true
        shift
        ;; 
      -f | --filter) 
        filter=${2}
        shift 2
        ;;
      -g | --ghtoken) 
        github_token=${2}
        shift 2
        ;;
      -h | --help) 
        usage_message
        return 0
        ;;
      -n | --name) 
        github_name=${2}
        shift 2
        ;;
      -t | --type) 
        github_type=${2}
        shift 2
        ;; 
      *) 
        break
        ;;
    esac
  done

  ####
  # CHECK INPUT
  # check if all required options are given

  # Check if the command is supported
  if [ "${command}" != "authenticated" ] && [ "${command}" != "public" ]; then
     print_error "please use a valid command."
     print_error "'${command}' unknown"
     usage_message
     return 1
  fi  
  
  # Check inputs for command 'public'
  if [ "${command}" == "public" ]; then 
    # are --type and --name set?
    if [ -z "${github_type}" ] || [ -z "${github_name}" ]; then
        print_error "please provide all required options to clone public repositories"
        if [ -z "${github_type}" ]; then
          print_error "--type = ${github_type}"
        fi
        if [ -z "${github_name}" ]; then
          print_error "--name = ${github_name}"
        fi
        usage_message
        return 1
    fi
    
    # does --type match one of the supported values? Supported values: 'users', 'orgs'    
    if [ "${github_type}" != "users" ] && [ "${github_type}" != "orgs" ]; then
        print_error "'${github_type}' unkown. please provide a valid type ('users' or 'orgs')."
        print_error "--type = ${github_type}"
        usage_message
        return 1
    fi
  fi

  # Check inputs for command 'all'
  if [ "${command}" == "authenticated" ]; then 
    # is --ghtoken set?
    if [ -z "${github_token}" ]; then
      print_error "please provide all required options to clone all repositories"
      print_error "--ghtoken = (hidden)"
      usage_message
      return 1
    fi

    if   [ "${github_affiliation}" != "" ] \
      && [ "${github_affiliation}" != "owner" ] \
      && [ "${github_affiliation}" != "collaborator" ] \
      && [ "${github_affiliation}" != "organization_member" ]; then
        print_error "please provide a valid affiliation option ('owner', 'collaborator', 'organization_member')"
        print_error "--affiliation = ${github_affiliation}"
        usage_message
        return 1
    fi
  fi
    
  ####
  # CORE LOGIC

  # Generating github api url
  print_info "Generating github api url..." false
  
  if [ "${command}" == "authenticated" ]; then
    # api url for all repositories accessable by the github token
    github_api_url="https://api.github.com/user/repos?per_page=100&access_token=${github_token}"
    if [ "${github_affiliation}" ]; then
      github_api_url+="&affiliation=${github_affiliation}"
    fi
  elif [ "${command}" == "public" ]; then
    # api url for public repositories
    # the github token can help with the github api request limit
    github_api_url="https://api.github.com/${github_type}/${github_name}/repos?per_page=100&access_token=${github_token}"
  else
    print_error "unexpected error generating the api url"
    return 1
  fi

  # disabled to hide the github_token if it is set
  # print_info "github api url: ${github_api_url}" false      
  
  # Gathering repos...
  print_info "Gathering repos..." false

  # while new repos are found... do
  while true
  do 
    # add new repos to the array of already identified repos
    # the repos array contains the urls to clone the repos
    # public repos are cloned by the git_url authenticated repos are cloned by the ssh_url
    github_api_response=$(curl -sSL "${github_api_url}"\&page=${page})
    if [ "${command}" == "public" ]; then
      mapfile -t -O "${#repos[@]}" repos < <(echo -e "${github_api_response}" | grep -e 'git_url' | cut -d \" -f 4)
    elif [ "${command}" == "authenticated" ]; then
      mapfile -t -O "${#repos[@]}" repos < <(echo -e "${github_api_response}" | grep -e 'ssh_url' | cut -d \" -f 4)
    else
      print_error "unexpected error collecting repo urls"
      return 1
    fi
    # if no new repo has been found break the loop
    # otherwise increase the repo_counter to the number of total repos found
    if [[ ${repo_counter} -eq ${#repos[@]} ]]; then
      break;
    else
      repo_counter=${#repos[@]}
    fi
    
    # increase the page number to query a new page on the next iteration of the loop
    ((page++))
  done
  
  # filter repositories based on --filter if --filter is set
  if [ "${filter}" ]; then
    mapfile -t repos < <( for repo in "${repos[@]}" ; do echo "${repo}" ; done | grep "${filter}" )
  fi

  # How many repos have been found matching the specified criteria
  print_info "${#repos[@]} Repositories found" false

  # clone each git repo in the repos array if it matches the filter
  for repo in "${repos[@]}"; do
    execute "git clone ${repo}"
  done
}

main "$@"