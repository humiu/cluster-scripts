# Kubernetes cluster management helper scripts

## Requirements

The following tools have to be installed and setup:

- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) with a config file in `~/.kube/config`
- [fzf](https://github.com/junegunn/fzf)

## Scripts & Usage

| Script                           | cURL command                    | Description                                                                                                                                                                                                                    |
| -------------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`launch-pma.sh`](launch-pma.sh) | `curl -sL pma.humiu.io \| bash` | Launch a PhpMyAdmin container and connect it<br>to a WordPress database that was created by<br>the [Bitnami WordPress helm chart](https://github.com/bitnami/charts/tree/master/bitnami/wordpress), or a chart<br>based on it. |

To use commandline arguments in combination with the **cURL commands**, just add a `-s -` followed by your arguments to the cURL command. E.g.:

**Without** arguments:

```bash
curl -sL pma.humiu.io | bash
```

**With** arguments:

```bash
curl -sL pma.humiu.io | bash -s - --help
# or:
curl -sL pma.humiu.io | bash -s - -c my-cluster
```
