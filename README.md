# Kubernetes cluster management helper scripts

## Requirements

The following tools have to be installed and setup:

- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) with a config file in `~/.kube/config`
- [fzf](https://github.com/junegunn/fzf)

## Scripts and usage

| Script                           | cURL command                    | Description                                                           |
| -------------------------------- | ------------------------------- | --------------------------------------------------------------------- |
| [`launch-pma.sh`](launch-pma.sh) | `curl -sL pma.humiu.io \| bash` | Launch a PhpMyAdmin container and connect it to a Wordpress database. |
