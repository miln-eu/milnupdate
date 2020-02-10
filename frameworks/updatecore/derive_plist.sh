#!/usr/bin/env sh

#
#  Miln Update - https://indie.miln.eu
#
#  Copyright © Graham Miln. All rights reserved. https://miln.eu
#
#  This package is subject to the terms of the Artistic License 2.0.
#  If a copy of the Artistic-2.0 was not distributed with this file, you can
#  obtain one at https://indie.miln.eu/licence
#

_SCRIPT="$0"
_REVISION="DO.NOT.DISTRIBUTE" # set by revision()
_DEFAULTS="/usr/bin/defaults"
#  Why `defaults`? `defaults` is user tool and `plutil` is developer tool. Apple is more
#  likely to change `plutil` in future releases.


showhelp() {
  echo "Usage: $_SCRIPT command ...[parameters]...
Commands:
  --help, h          Show this help message.
  --insert [sets]    Insert set of key values.

Sets:
  info            Common Info.plist keys.
  installlaunchd  Insert installer tool's launchd keys.
  installtool     Insert installer tool's Info.plist client keys.
  installauth     Insert installer authority Info.plist keys.

Parameters:
  --input, i   [/path/to/plist]   Specifies the path to read the input plist from.
  --output, o  [/path/to/plist]   Specifies the path to write the output plist to.

Description:
This script inserts values into property list (plist) files. The values
that are inserted depends on the first argument.

The script is expected to be run by Xcode as a Run Script phase of the build
process.

This script is needed because Xcode substitutions only within target
Info.plist files. We have other plist files that need compile time
substitutions. Additionally, substitutions are needed for dictionary
keys within plist files; dictionary key substitutions are not
currently supported by Xcode.
"
}

_err() {
  printf "error:${_SCRIPT}:0: $1\n" >&2
  return 1
}

revision() {
  # Assume git source code control; https://stackoverflow.com/questions/7853332
  _REVISION=$(git log -1 --date=format:'%Y%m%d' "--pretty=format:%cd.%h")
  if [ -z ${_REVISION} ]; then
    _REVISION="FERAL.DO.NOT.DISTRIBUTE"
  fi
}

copyPropertyList() {
  input="$1"
  output="$2"
  if ! cp "$input" "$output"; then
    _err "Can not copy input plist to output path."
    return 1
  fi
}

insertString() {
  plist="$1"
  key="$2"
  value="$3"
  if [ -z "${value}" ]; then
    _err "Missing value to insert for key '${key}'."
    return 1
  fi
  
  if ! "${_DEFAULTS}" write "$plist" "$key" -string "${value}"; then
    _err "Unable to set '${key}' in property list."
    return 1
  fi
}

insertStringFromEnv() {
  plist="$1"
  key="$2"
  envKey="$3"
  value=$(echo "${!envKey}")
  if [ -z "${value}" ]; then
    _err "Missing required environment value: ${envKey}"
    return 1
  fi
  
  insertString "${plist}" "${key}" "${value}"
}

insertInfoSet() {
  plist="$1"
  
  insertStringFromEnv "$plist" "CFBundleShortVersionString" "MILNUPDATE_VERSION"
  insertString        "$plist" "CFBundleVersion" "${_REVISION}"
}

insertInstallLaunchdSet() {
  plist="$1"

  insertStringFromEnv "$plist" "Label" "PRODUCT_BUNDLE_IDENTIFIER"
  
  if ! $_DEFAULTS write "$plist" "MachServices" -dict "${PRODUCT_BUNDLE_IDENTIFIER}" -bool "true"; then
	_err "Unable to set 'MachServices' in property list."
	return 1
  fi
}

insertInstallToolSet() {
  plist="$1"
  
  insertStringFromEnv "$plist" "CFBundleName" "PRODUCT_NAME"
  insertStringFromEnv "$plist" "CFBundleIdentifier" "PRODUCT_BUNDLE_IDENTIFIER"
  insertStringFromEnv "$plist" "CFBundleExecutable" "PRODUCT_BUNDLE_IDENTIFIER"

  extra=""
  if [ ! -z "${MILNUPDATE_TOOL_ADDITIONAL_POLICY_CHECK}" ]; then
    extra=" and ${MILNUPDATE_TOOL_ADDITIONAL_POLICY_CHECK}"
  fi

  v1="'identifier \"${MILNUPDATE_AUTH_APP_BUNDLE}\" and anchor apple generic and certificate leaf[subject.CN] = \"${MILNUPDATE_APP_CERTIFICATE}\"${extra}'"
  v2="'identifier \"${MILNUPDATE_XPC_INSTALL_BUNDLE}\" and anchor apple generic and certificate leaf[subject.CN] = \"${MILNUPDATE_APP_CERTIFICATE}\"${extra}'"
  
  if ! $_DEFAULTS write "$plist" "SMAuthorizedClients" -array "${v1}" "${v2}"; then
	_err "Unable to set 'SMAuthorizedClients' in property list."
	return 1
  fi
}

insertInstallAuthSet() {
  plist="$1"
    
  extra=""
  if [ ! -z "${MILNUPDATE_TOOL_ADDITIONAL_POLICY_CHECK}" ]; then
    extra=" and ${MILNUPDATE_TOOL_ADDITIONAL_POLICY_CHECK}"
  fi
    
  v1="'identifier \"${MILNUPDATE_TOOL_BUNDLE}\" and anchor apple generic and certificate leaf[subject.CN] = \"${MILNUPDATE_APP_CERTIFICATE}\"${extra}'"
  
  if ! $_DEFAULTS write "$plist" "SMPrivilegedExecutables" -dict "${MILNUPDATE_TOOL_BUNDLE}" "${v1}"; then
	_err "Unable to set 'SMPrivilegedExecutables' in property list."
	return 1
  fi
}

insert() {
  key_sets="$1"
  input="$2"
  output="$3"
  
  if [ -z "${output}" ]; then
    output=input
  else  
	if ! copyPropertyList "$input" "$output"; then
	  return 1
	fi
  fi
  
  for i in $key_sets; do
    case "${i}" in
      info)
        insertInfoSet "$output"
        ;;
      installlaunchd)
        insertInstallLaunchdSet "$output"
        ;;
      installtool)
        insertInstallToolSet "$output"
        ;;
      installauth)
        insertInstallAuthSet "$output"
        ;;
      *)
        _err "Unknown insertion set: $i"
        return 1
        ;;
    esac
  done
}

main() {
  [ -z "$1" ] && showhelp && return

  # Determine runtime variables
  revision
  
  # Parse command line options
  _CMD=""
  _key_sets=""
  _input_path=""
  _output_path=""
  
  while [ ${#} -gt 0 ]; do
    case "${1}" in
      --help | -h)
        showhelp
        return
        ;;
      --insert)
        _CMD="insert"
        _key_sets="$2"
        shift
        ;;
      --input | -i)
        _input_path="$2"
        shift
        ;;
      --output | -o)
        _output_path="$2"
        shift
        ;;
      *)
        _err "Unknown parameter : $1"
        return 1
        ;;
    esac
    
    shift 1
  done
  
  case "${_CMD}" in
  insert)
    insert "$_key_sets" "$_input_path" "$_output_path"
    ;;
  esac
  
}

main "$@"

#  Thanks to https://github.com/Neilpang/acme.sh for the postive influence. Yes, this
#  script is over engineered.