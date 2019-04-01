# file with common functions 

function check_rc {
  rc=$1
  text=$2
  if [[ "$rc" != "0" ]]; then
    echo "nonzero RC in ${text}"
    return 1
  else
    return 0
  fi
}

function showhelp {
  echo -e "Quick help"
  echo -e "=========="
  echo -e "--rebuild\trebuild the Singularity image"
  echo -e "--nopurge\twill not clean the (possibly) found sw image and will continue with the existing one"
  echo -e "--justshell\tjust do the init and start shell in the singularity image"
  echo -e "--version NAME|-v NAME\tif specified, will force the version name instead of current vYYMMDDHHMM"
  echo -e "--help|-?|-h\tshows this help"
}
