#!/usr/bin/env bash

# helper variables to make text bold
bold_start=$(tput bold)
bold_end=$(tput sgr0)

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--context)
      CONTEXT="$2"
      shift 2
      if [ $? -gt 0 ]; then
        echo "You must pass the kubectl context as second argument to -c or --context!" >&2
        exit 1
      fi
    ;;

    --context=*)
      CONTEXT="${1#*=}"
      shift
    ;;

    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      if [ $? -gt 0 ]; then
        echo "You must pass the namespace as second argument to -n or --namespace!" >&2
        exit 1
      fi
    ;;

    --namespace=*)
      NAMESPACE="${1#*=}"
      shift
    ;;

    -d|--deploy|--deployment)
      DEPLOYMENT="$2"
      shift 2
      if [ $? -gt 0 ]; then
        echo "You must pass the deployment name as second argument to -d, --deploy or --deployment!" >&2
        exit 1
      fi
    ;;

    --deploy=*|--deployment=*)
      DEPLOYMENT="${1#*=}"
      shift
    ;;

    -p|--port)
      LOCAL_PORT="$2"
      shift 2
      if [ $? -gt 0 ]; then
        echo "You must pass the port as second argument to -p or --port!" >&2
        exit 1
      fi
    ;;

    --port=*)
      LOCAL_PORT="${1#*=}"
      shift
    ;;

    -h|--help)
      echo -e "This script will launch a PhpMyAdmin container in a kubernetes"
      echo -e "cluster and connect it to a wordpress installation."
      echo -e ""
      echo -e "USAGE:"
      echo -e "\t$(basename "$0")"
      echo -e "\t\t[(-c | --context) <KUBECTL CONTEXT>]"
      echo -e "\t\t[(-n | --namespace) <NAMESPACE>]"
      echo -e "\t\t[(-d | --deploy | --deployment) <DEPLOYMENT>]"
      echo -e "\t\t[(-p | --port) <LOCAL PORT>]"
      echo -e "\t\t[-h | --help]"
      echo -e ""
      echo -e "OPTIONS:"
      echo -e "\t-c, --context <KUBECTL CONTEXT>"
      echo -e "\t\tUse another context of the kubectl config file than the current one."
      echo -e ""
      echo -e "\t-n, --namespace <NAMESPACE>"
      echo -e "\t\tThis argument specifies the namespace in which the wordpress instance is deployed."
      echo -e ""
      echo -e "\t-d, --deploy, --deployment <DEPLOYMENT>"
      echo -e "\t\tThe kubernetes deployment name of the wordpress instance."
      echo -e ""
      echo -e "\t-p, --port <LOCAL PORT>"
      echo -e "\t\tThe local port to which the PhpMyAdmin application is getting forwarded to."
      echo -e ""
      echo -e "\t-h, --help"
      echo -e "\t\tPrint this help text."
      exit 0
    ;;

    *)
      if [ "${1// }" ]; then
        echo "Unknown option: $1" >&2
        exit 1
      fi
      shift
    ;;
  esac
done

function ensure_fzf_is_installed() {
  if ! [ -x "$(command -v fzf)" ]; then
    echo "fzf (https://github.com/junegunn/fzf) has to be installed in order to select the namespace or deployment!"
    echo -e "Alternatively use the --namespace or --deployment arguments (find out more with \"$(basename "$0") --help\")."
    exit 1
  fi
}

if [ -z "$NAMESPACE" ]; then
  ensure_fzf_is_installed

  echo -n "Select the namespace of the WordPress instance: "
  NAMESPACE="$(
    kubectl --context="$CONTEXT" get ns --output="name" | sed -e "s/^[^/]*\///g" | fzf
  )"

  [ -z "$NAMESPACE" ] && echo "Cancelled ..." && exit 1

  echo -e "\r\033[KNamespace:\t$NAMESPACE"
fi

if [ -z "$DEPLOYMENT" ]; then
  ensure_fzf_is_installed

  WORDPRESS_DEPLOYMENTS=($(
    kubectl --context="$CONTEXT" get deploy --namespace="$NAMESPACE" --output="name" --selector="app.kubernetes.io/name=wordpress" | sed -e "s/^[^/]*\///g"
  ))

  if (( ${#WORDPRESS_DEPLOYMENTS[@]} == 0 )); then
    echo "Could not find any WordPress deployments in namespace $NAMESPACE!" >&2
    exit 1
  fi

  echo -n "Select the deployment name of the WordPress instance: "
  DEPLOYMENT="$(
    printf '%s\n' "${WORDPRESS_DEPLOYMENTS[@]}" | fzf
  )"

  [ -z "$DEPLOYMENT" ] && echo "Cancelled ..." && exit 1

  echo -e "\r\033[KDeployment:\t$DEPLOYMENT"
fi

if [ -z "$PORT" ]; then
  DEFAULT_LOCAL_PORT=8080
  while $(nc -z 127.0.0.1 $DEFAULT_LOCAL_PORT &>/dev/null); do
    ((DEFAULT_LOCAL_PORT++))
  done

  read -p "Local port to which PMA is getting forwarded to: [default=${bold_start}${DEFAULT_LOCAL_PORT}${bold_end}] " LOCAL_PORT
  [ -z "$LOCAL_PORT" ] && LOCAL_PORT="$DEFAULT_LOCAL_PORT"
  while $(nc -z 127.0.0.1 $LOCAL_PORT &>/dev/null); do
    read -p "Local port $LOCAL_PORT is already in use. Please enter another local port: [default=${bold_start}${DEFAULT_LOCAL_PORT}${bold_end}] " LOCAL_PORT
    [ -z "$LOCAL_PORT" ] && LOCAL_PORT="$DEFAULT_LOCAL_PORT"
  done
fi

CLUSTER_DOMAIN="$(
  kubectl --context="$CONTEXT" get configmap --namespace="kube-system" cluster-dns -o jsonpath="{.data.clusterDomain}"
)"
DB_HOST="${DEPLOYMENT}-mariadb.${NAMESPACE}.svc.${CLUSTER_DOMAIN}"
DB_PORT="3306"
DB_NAME="bitnami_wordpress"
DB_USER="bn_wordpress"
PMA_IMAGE_NAME="phpmyadmin"
PMA_CONTAINER_NAME="phpmyadmin-for-${DEPLOYMENT}"
CONTAINER_PORT=80

# WORDPRESS_PASSWORD="$(
#   kubectl --context="$CONTEXT" get secret --namespace="$NAMESPACE" "$DEPLOYMENT" -o jsonpath="{.data.wordpress-password}" | base64 --decode
# )"

DB_PASSWORD="$(
  kubectl --context="$CONTEXT" get secret --namespace="$NAMESPACE" "${DEPLOYMENT}-mariadb" -o jsonpath="{.data.mariadb-password}" | base64 --decode
)"

# DB_ROOT_PASSWORD="$(
#   kubectl --context="$CONTEXT" get secret --namespace="$NAMESPACE" "${DEPLOYMENT}-mariadb" -o jsonpath="{.data.mariadb-root-password}" | base64 --decode
# )"

echo ""
echo -n "Starting PhpMyAdmin container ... "

kubectl --context="$CONTEXT" run "$PMA_CONTAINER_NAME" \
  --namespace="$NAMESPACE" \
  --image="$PMA_IMAGE_NAME" \
  --port=$CONTAINER_PORT \
  --env="PMA_HOST=$DB_HOST" \
  --env="PMA_PORT=$DB_PORT" \
  >/dev/null

kubectl --context="$CONTEXT" wait --for=condition=ready --timeout=60s "pod/${PMA_CONTAINER_NAME}" --namespace="$NAMESPACE" >/dev/null

if [ $? -eq 0 ]; then
  echo -ne "\r\033[K"
  echo -e "\tUSER:\t$DB_USER"
  echo -e "\tP/W:\t$DB_PASSWORD"
  echo -e "\tURL:\thttp://localhost:$LOCAL_PORT/index.php?route=/database/structure&server=1&db=bitnami_wordpress"
  echo ""

  kubectl --context="$CONTEXT" port-forward --namespace="$NAMESPACE" "pod/${PMA_CONTAINER_NAME}" $LOCAL_PORT:$CONTAINER_PORT >/dev/null
  echo ""
else
  echo "Creating PhpMyAdmin container failed! Aborting ..."
fi

kubectl --context="$CONTEXT" delete pod "$PMA_CONTAINER_NAME" --namespace="$NAMESPACE" --wait=false >/dev/null
