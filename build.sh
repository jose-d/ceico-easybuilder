#!/bin/bash

# parse arguments:

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --easybuild_sourcepath)
      easybuild_sourcepath="$2"
      shift # past argument
      shift # past value
      ;;
    --easybuild_buildpath)
      easybuild_buildpath="$2"
      shift # past argument
      shift # past value
      ;;
    --custom_easybuilds_dir)
      custom_easybuilds_dir="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
    esac
  done
set -- "${POSITIONAL[@]}" # restore positional parameters

# check if we have all mandatory arguments

echo "checking mandatory arguments.."

if [ -d "${easybuild_sourcepath}" ]; then
  echo "--easybuild_sourcepath (EB download location) defined as ${easybuild_sourcepath} .. LGFM"
  export EASYBUILD_SOURCEPATH=${easybuild_sourcepath}     # from CLI argument
else
  echo "--easybuild_sourcepath (EB download location) undefined/it's not directory. BAD"
  exit 1
fi

if [ -d "${easybuild_buildpath}" ]; then
  echo "--easybuild_buildpath defined as ${easybuild_buildpath} .. LGFM"
else
  echo "--easybuild_buildpath undefined/it's not directory. BAD"
  exit 1
fi

# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPT=$(readlink -f $0)	# Absolute path to this script.
SCRIPTPATH=$(dirname $SCRIPT)	# Absolute path this script is in. /home/user/bin

# reset the module cache, just for case:
rm ~/.lmod.d/.cache -rf

# load the EasyBuild environment
module purge
module use $EASYBUILD_PREFIX/modules/all
module load EasyBuild	#this will load latest EB available

# deal with licenses
export INTEL_LICENSE_FILE="/home/soft/intel/license.lic"

#
# stable software:
# - we can use the upstream easyconfigs
# 
stable_list_file="${SCRIPTPATH}/easybuild_stable.swlist"
stable_path_prefix=$(readlink -f ${EBROOTEASYBUILD}/lib/python2.7/site-packages/easybuild_easyconfigs-*/easybuild/easyconfigs)

echo "processing ${stable_list_file}"

while IFS='' read -r line || [[ -n "$line" ]]; do
  #echo "line: $line"
  [[ "$line" =~ ^#.*$ ]] && continue # regexp matching '#' = commented lines we don't care
  command="eb -r --buildpath=${easybuild_buildpath} ${stable_path_prefix}/${line}"
  echo "================================================================================"
  echo "command: ${command}"
  eval ${command}
done < "${stable_list_file}"

#
# site-specific and unstable software:
# - we use easyconfigs cloned from git.
#

if [ -d "${custom_easybuilds_dir}" ]; then
  echo "--custom_easybuilds_dir specified to ${custom_easybuilds_dir} .. let's process custom easyconfigs too."
else
  echo "--custom_easybuilds_dir - not specified, we're done."
  exit 0
fi

# exit 0 #TODO: exit for now.. perhaps we could have some swtich for this...

site_specific_list_file="${SCRIPTPATH}/easybuild_specific.swlist"
echo "processing ${specific_list_file}"


while IFS='' read -r line || [[ -n "$line" ]]; do
  #echo "line: $line"
  [[ "$line" =~ ^#.*$ ]] && continue # regexp matching '#' = commented lines we don't care
  command="eb --buildpath=${easybuild_buildpath} -r ${custom_easybuilds_dir} ${custom_easybuilds_dir}/${line}"
  echo "================================================================================"
  echo "command: ${command}"
  eval ${command}
done < "${site_specific_list_file}"

