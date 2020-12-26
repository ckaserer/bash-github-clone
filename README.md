# bash-github-clone

A little script to easily clone multiple repositories from github. This is especially handy if you want to set your development environment on a new system.

```bash
github-clone.sh is designed to clone github repositories by querying the github api to gather 
repo URLs.

Usage:
  github-clone.sh <command> [OPT ..]
    
  Examples:
  # clone all public repositories from the user ckaserer
  github-clone.sh public --type users --name ckaserer

  # clone all repositories to which the github token has access
  github-clone.sh authenticated --ghtoken <GH_TOKEN>

  # clone all repositories owned by the user
  github-clone.sh authenticated --ghtoken <GH_TOKEN> --affiliation owner

  # clone all my ansible related repos
  github-clone.sh authenticated --ghtoken <GH_TOKEN> --affiliation owner --filter ansible-role

  Available Commands:
    public 
      -n | --name)          ... specify the name of the github entity. e.g. your username or 
                                orgname
      -t | --type)          ... specify the type of the github entity. Either 'users' or 'orgs'

    authenticated
      -g | --ghtoken)       ... github access token used to list repos (incl. private and orgs). 
      -a | --affiliation)   ... clone only repos matching the specified affiliation (optional)
                                available affiliations: owner / colaborator / oranization_member
                                if no affiliation is specified, all repos will be cloned

    Additional Options:
      -f | --filter)        ... filter repos by string

      -d | --dryrun)        ... dryrun
      -h | --help)          ... help
```

----

## Source

* [https://stackoverflow.com/questions/19576742/how-to-clone-all-repos-at-once-from-github](https://stackoverflow.com/questions/19576742/how-to-clone-all-repos-at-once-from-github)
* [https://github.com/ckaserer/bash-script-collection](https://github.com/ckaserer/bash-script-collection)
