#!/bin/bash

my_dir="$(dirname "$0")"
source "$my_dir/functions.sh"

# parse arguments:

rebuild=false
nopurge=false
justshell=false

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --rebuild)	#rebuild the Singularity image
      rebuild=true
      shift # past argument
      ;;
    --nopurge)
      nopurge=true
      shift # past argument
      ;;
    --justshell)
      justshell=true
      shift # past argument
      ;;
    --version|-v)
      versionstring="$2"
      shift # past argument
      shift # past value
      ;;
    --help|-?|-h)
      showhelp
      exit 0	# after showing help we can end this.
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
    esac
  done
set -- "${POSITIONAL[@]}" # restore positional parameters

# CONFIG

# dir where to git clone the custom easyconfigs and easybuilds
# subdir with random name will be created to allow parallel runs:
custom_easybuild_dir='/tmp/ce-custom'

# dir where to build the singularity image
container_image_dir='/mnt/local-scratch/u/jose/easybuilder_image'

# git URLs from where to clone custom easyconfigs and easybuilds:
custom_easyblocks_git_URL='git@github.com:jose-d/ceico-easyblocks.git'
custom_easyblocks_dir='ceico-easyblocks'

custom_easyconfigs_git_URL='git@github.com:jose-d/ceico-easyconfigs.git'
custom_easyconfigs_dir='ceico-easyconfigs'

# where the builddir will be created:
builddir_root='/dev/shm'

# Singularity-related config:
singularity_image_git_URL='git@github.com:jose-d/easybuild-singularity-testbench.git'
singularity_image_git_projectname='easybuild-singularity-testbench'
singularity_lmod_module_name='singularity/3.0.1'
singularity_recipe_filename='container.def'
singularity_image_name='container.img'

# sw tree host directory
sw_tree_host_dir='/mnt/local-scratch/u/jose/666'
additional_bind_pair_1='/home/soft:/home/soft'	# for intel licensing server etc. if unsed, comment it out in the singularity statement too..

# eb download path
eb_download_path='/home/users/jose/Downloads'


# PREPARE

instance_id=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1) # random 16-character string indetifying build
echo "instance_id: ${instance_id}"

# * check if we have version string or we should generate new one:

if [ -z "$versionstring" ]; then
  versionstring=$(date +"v%y%m%d%H%M")
fi

sw_tree_system_dir="/sw/local/$versionstring"

echo "versionstring: ${versionstring}"

# * directory for git clones:

easybuild_dir="${custom_easybuild_dir}/${instance_id}"
mkdir -p ${easybuild_dir}/logs
check_rc $? "mkdir -p ${easybuild_dir}/logs"
echo "easybuild_dir: ${easybuild_dir}"

# * build dir

easybuild_build_dir="${builddir_root}/${instance_id}"
mkdir -p ${easybuild_build_dir}
check_rc $? "mkdir -p ${easybuild_build_dir}"
echo "easybuild_build dir: ${easybuild_build_dir}"

# get our path:
our_script=$(readlink -f $0)
our_script_path=$(dirname $our_script)

mkdir -p ${container_image_dir}/logs


cd ${easybuild_dir}


echo "Cloning custom easyconfigs from ${custom_easyconfigs_git_URL} to ${easybuild_dir}.."
touch ${easybuild_dir}/logs/git.log
git clone ${custom_easyconfigs_git_URL} >> ${easybuild_dir}/logs/git.log 2>&1
check_rc $? "git clone ${custom_easyconfigs_git_URL}"
echo 'done.'

# git clone to have the develop branch of easybuild-easyconfigs,
# change the structure into flat one,
# and remove the original dirs to be not so space-hungry..
# -> then we have in 
# ${easybuild_dir}/easybuild-easyconfigs-develop/flat
# develop branch of EB
#
echo "Cloning easybuild-easyconfigs into ${easybuild_dir}/easybuild-easyconfigs-develop .."
git clone --single-branch --branch develop https://github.com/easybuilders/easybuild-easyconfigs.git easybuild-easyconfigs-develop >> ${easybuild_dir}/logs/git.log 2>&1 \
 && echo '.. flattening the structure ..' \
 && cd easybuild-easyconfigs-develop \
 && mkdir flat \
 && cd easybuild \
 && find . -type f -exec cp {} ../flat \; \
 && rm ./easybuild -rf \
 && rm ./test -rf \
 && echo 'done.'

# deal with the Singularity image build

module load ${singularity_lmod_module_name}
singularity_command=$(which singularity)

noimage=false
if [ -f "${container_image_dir}/${singularity_image_name}" ]; then
  echo "INFO: some image is already present in path ${container_image_dir}/${singularity_image_name}"
else
  echo "INFO: no image is present in ${container_image_dir}/${singularity_image_name}"
  noimage=true
fi

if $rebuild || $noimage; then
  if [ -f "${container_image_dir}/${singularity_image_name}" ]; then
    echo "INFO: purging old image.."
    rm -f ${container_image_dir}/${singularity_image_name}
  fi
  cd ${container_image_dir}
  touch ${container_image_dir}/logs/git.log
  echo "Cloning ${singularity_image_git_URL} into ${container_image_dir}.."
  git clone ${singularity_image_git_URL} >> ${container_image_dir}/logs/git.log 2>&1
  cd ${container_image_dir}/${singularity_image_git_projectname}
  touch ${container_image_dir}/logs/singularity.log
  echo "singularity command to be used: $singularity_command"
  echo "..logging into ${container_image_dir}/logs/singularity.log"
  sudo ${singularity_command} build ${container_image_dir}/${singularity_image_name} ${container_image_dir}/${singularity_image_git_projectname}/${singularity_recipe_filename} >> ${container_image_dir}/logs/singularity.log 2>&1
  check_rc $? "singularity build"
  echo "singularity image build done."
fi

# make/cleanup the sw tree directory

if $nopurge; then
  echo "--nopurge specified, not cleaning anything.."
else
  if [ -d "${sw_tree_host_dir}" ]; then
    #dir is there, let's do the cleanup
    rm -rf ${sw_tree_host_dir} && mkdir ${sw_tree_host_dir}
    check_rc $? "cleanup of ${sw_tree_host_dir}"
    echo "${sw_tree_host_dir} cleaned and re-created."
  else
    #dir is not yet there, let's create it
    mkdir -p ${sw_tree_host_dir}
    check_rc $? "mkdir ${sw_tree_host_dir}"
    echo "${sw_tree_host_dir} created."
  fi
fi

# start the Singularity (user is enough now..) 
# TODO: replace the shell with command
# we need to run it as least:
# /scripts/build.sh --easybuild_sourcepath /downloads --easybuild_buildpath /dev/shm/Noy1YB0YWKRJEtvO

if $justshell; then
  singularity_action="shell"
else
  singularity_action="exec"
fi


${singularity_command} ${singularity_action} \
  -B ${easybuild_dir}:/easybuild_custom \
  -B ${our_script_path}:/scripts \
  -B ${sw_tree_host_dir}:${sw_tree_system_dir} \
  -B ${eb_download_path}:/downloads \
  -B ${additional_bind_pair_1} \
  ${container_image_dir}/${singularity_image_name} \
  /scripts/build.sh --easybuild_sourcepath /downloads \
                    --easybuild_buildpath ${easybuild_build_dir} \
                    --custom_easybuilds_dir /easybuild_custom/${custom_easyconfigs_dir} \
                    --develop_upstream_dir /easybuild_custom/easybuild-easyconfigs-develop/flat


# CLEANUP

rm -rf ${easybuild_build_dir}
#builddir - should be empty when build was OK.. but if not, lot of things could be there..
rm -rf ${easybuild_dir}
# the one with git clones..
