#!/usr/bin/env sh

#
#  Miln Update
#
#  Copyright © 2018 Graham Miln. All rights reserved. https://miln.eu
#
#  This package is subject to the terms of the Artistic License 2.0.
#  If a copy of the Artistic-2.0 was not distributed with this file, you can
#  obtain one at https://indie.miln.eu/licence
#

_SCRIPT="$0"

showhelp() {
  echo "Usage: $_SCRIPT --app [path/to/application]
Commands:
  --help, h                        Show this help message.
  --app, a  [path/to/application]  Specifies the path to the application to package.
  --pkg, p  [/path/to/pkg]         Specifies the path to write the package to.
  --noquit                         Do not quit and relaunch the application.
  --norelocation                   Do not update applications outside of /Applications.

Description:
Create an application package suitable for distribution and use with Miln Update.

This script provides a wrapper around Apple's pkgbuild and productbuild; these
two tools should be preferred for more complex installations and updates.
"
}

_err() {
  printf "[ERROR] %s: %s\\n" "${_SCRIPT}" "$1" >&2
  return 1
}

createAppInstaller() {
  app_path="$1"
  pkg_path="$2"
  identifier="$3"
  revision="$4"
  version="$5"
  noquit="$6"
  norelocation="$7"
  
  app_name=$(basename "$app_path")

  echo "[BUILDING]"

  # Prepare the files for the installer
  temp_dir=$(mktemp -d -t "pkg-app")
  trap 'rm -rf -- "$temp_dir"' INT TERM HUP EXIT
    
  # Copy the application
  installer_contents_path="${temp_dir}/contents"
  installer_contents_app_path="${installer_contents_path}/${app_name}"
  
  # Strip quarantine and access control lists from application copy 
  if ! ditto -v --noqtn --noacl "$app_path" "${installer_contents_app_path}"; then
    _err "Can not copy application."
    return 1
  fi
  
  # Prepare pre and post flight scripts
  installer_scripts_path="${temp_dir}/scripts"
  if ! mkdir -p "${installer_scripts_path}"; then
    _err "Can not create scripts directory."
    return 1
  fi
 
  if [ -z "${noquit}" ]; then
 
    # Pre-flight script quits the application using an Open Scripting Architecture (OSA) script (AppleScript)
    printf "%s\\n" '#!/usr/bin/osascript' \
    'try' \
    "  set appID to \"${identifier}\"" \
    '  if application id appID is running then' \
    '    tell application id appID to quit' \
    '  end if' \
    'end try' >"${installer_scripts_path}/preinstall"
    chmod +x "${installer_scripts_path}/preinstall"
  
    # Post-flight script re-launches installed application
    printf "%s\\n" '#!/bin/sh' "/usr/bin/open -b '${identifier}' --args '--eu.miln.update.postinstall=YES'" >"${installer_scripts_path}/postinstall"
    chmod +x "${installer_scripts_path}/postinstall"

  fi # noquit

  # Create the application package
  app_pkg="app-${revision}.pkg"
  app_pkg_path="${temp_dir}/${app_pkg}"
  if ! /usr/bin/pkgbuild --quiet --identifier "${identifier}" --version "${revision}" --ownership recommended --install-location "/Applications" --scripts "${installer_scripts_path}" --component "${installer_contents_app_path}" "${app_pkg_path}"; then
    _err "Can not create installer package."
    return 1
  fi
  
  # Create the installer distribution file
  relocation=""
  # ...relocation allows the user to update an application outside of /Applications
  if [ -z "${norelocation}" ]; then
    relocation=$(printf "%s\\n" \
    "    <pkg-ref id=\"${identifier}\">" \
    '        <relocate search-id="s0">' \
    "            <bundle id=\"${identifier}\"/>" \
    '        </relocate>' \
    '    </pkg-ref>' \
    '    <locator>' \
    '        <search id="s0" type="component">' \
    "            <bundle CFBundleIdentifier=\"${identifier}\" path=\"/Applications/${app_name}\"/>" \
    '        </search>' \
    '    </locator>')
  fi
  
  app_title=$(basename "$app_path" ".app")
  distribution_xml_path="${temp_dir}/distribution.xml"
  printf "%s\\n" '<?xml version="1.0" encoding="utf-8"?>' \
    '<installer-gui-script minSpecVersion="1" authoringTool="eu.miln.update">' \
    "    <title>${app_title} v${version}</title>" \
    '    <options customize="never" require-scripts="false"/>' \
    '    <domains enable_localSystem="true"/>' \
    '    <choices-outline>' \
    '        <line choice="c0">' \
    "            <line choice=\"${identifier}\"/>" \
    '        </line>' \
    '    </choices-outline>' \
    '    <choice id="c0"/>' \
    "    <choice id=\"${identifier}\">" \
    "        <pkg-ref id=\"${identifier}\"/>" \
    '    </choice>' \
    "    <pkg-ref id=\"${identifier}\" version=\"${revision}\" onConclusion=\"none\">${app_pkg}</pkg-ref>" \
    "${relocation}" \
    '</installer-gui-script>' >"${distribution_xml_path}"  
  
  # Create the installer package
  if ! /usr/bin/productbuild --distribution "${distribution_xml_path}" --package-path "$(dirname "${app_pkg_path}")" "${pkg_path}"; then
    _err "Can not create installer package."
    return 1
  fi
  
  signed_pkg=$(basename "${pkg_path}" .pkg)
  echo "[SUCCESS]"
  echo "${pkg_path} has been created. This package is NOT SIGNED. Before distribution you MUST sign the package:"
  echo ""
  echo "  /usr/bin/productsign --sign <identity> ${pkg_path} ${signed_pkg}-signed.pkg"
  echo ""
  echo "Need help? Need a more complex package or installation process? Commercial support for Miln Update is available at <https://miln.eu>"
}

main() {
  [ -z "$1" ] && showhelp && return

  # Parse command line options
  _app_path=""
  _pkg_path=""
  _no_quit=""
  _no_relocation=""
  
  while [ ${#} -gt 0 ]; do
    case "${1}" in
      --help | -h)
        showhelp
        return
        ;;
      --app | -a)
        # Ensure absolute path
        _app_path=$(cd "$(dirname "$2")" || (_err "Invalid app path"; return 1); pwd)/$(basename "$2")
        shift
        ;;
      --pkg | -p)
        _pkg_path="$2"
        shift
        ;;
      --noquit)
        _no_quit="1"
        shift
        ;;
      --norelocation)
        _no_relocation="1"
        shift
        ;;
      *)
        _err "Unknown parameter : $1"
        return 1
        ;;
    esac
    
    shift 1
  done
  
  # Application path is required
  if [ -z "${_app_path}" ]; then
    _err "Application path is required."
    return 1
  fi
  
  # Prepare path to application's Info.plist and check for non-zero size
  _app_info_path="${_app_path}/Contents/Info.plist"
  if [ -s "${_app_bundle_identifier}" ]; then
    _err "Application missing required: ${_app_info_path}"
    return 1
  fi

  # Extract values from application's Info.plist
  
  # ...application bundle identifier
  _app_bundle_identifier=$(defaults read "${_app_info_path}" CFBundleIdentifier)
  if [ -z "${_app_bundle_identifier}" ]; then
    _err "Application missing required: CFBundleIdentifier within ${_app_info_path}"
    return 1
  fi
  
  # ...application version
  _app_version=$(defaults read "${_app_info_path}" CFBundleShortVersionString)
  if [ -z "${_app_version}" ]; then
    _err "Application missing required: CFBundleShortVersionString within ${_app_info_path}"
    return 1
  fi
  
  # ...application revision
  _app_revision=$(defaults read "${_app_info_path}" CFBundleVersion)
  if [ -z "${_app_revision}" ]; then
    _err "Application missing required: CFBundleVersion within ${_app_info_path}"
    return 1
  fi
  
  # Derive a default package name based on the application name
  if [ -z "${_pkg_path}" ]; then
    _pkg_path=$(basename "${_app_path}" .app)
    _pkg_path="${_pkg_path}-${_app_version}.pkg"
    _pkg_path=$(echo "${_pkg_path}" | tr '[:upper:]' '[:lower:]')
    _pkg_path=$(echo "${_pkg_path}" | tr '[:blank:]' '-')
  fi
  
  echo "App: ${_app_path} (${_app_bundle_identifier}/${_app_version}/${_app_revision})"
  echo "Pkg: ${_pkg_path}"
  
  createAppInstaller "${_app_path}" "${_pkg_path}" "${_app_bundle_identifier}" "${_app_revision}" "${_app_version}" "${_no_quit}" "${_no_relocation}"
}

main "$@"

#  Thanks to https://github.com/Neilpang/acme.sh for the positive influence.