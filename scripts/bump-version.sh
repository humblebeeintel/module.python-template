#!/bin/bash
set -euo pipefail


## --- Base --- ##
# Getting path of this script file:
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
cd "${_PROJECT_DIR}" || exit 2


# Loading .env file (if exists):
if [ -f ".env" ]; then
	# shellcheck disable=SC1091
	source .env
fi
## --- Base --- ##


## --- Variables --- ##
# Load from envrionment variables:
VERSION_FILE_PATH="${VERSION_FILE_PATH:-./src/my_module01/__version__.py}"


_BUMP_TYPE=""

# Flags:
_IS_COMMIT=false
_IS_TAG=false
_IS_PUSH=false
## --- Variables --- ##


## --- Main --- ##
main()
{
	## --- Menu arguments --- ##
	if [ -n "${1:-}" ]; then
		for _input in "${@:-}"; do
			case ${_input} in
				-b=* | --bump-type=*)
					_BUMP_TYPE="${_input#*=}"
					shift;;
				-c | --commit)
					_IS_COMMIT=true
					shift;;
				-t | --tag)
					_IS_TAG=true
					shift;;
				-p | --push)
					_IS_PUSH=true
					shift;;
				*)
					echo "[ERROR]: Failed to parsing input -> ${_input}"
					echo "[INFO]: USAGE: ${0}  -b=*, --bump-type=* [major | minor | patch] | -c, --commit | -t, --tag | -p, --push"
					exit 1;;
			esac
		done
	fi
	## --- Menu arguments --- ##


	if [ -z "${_BUMP_TYPE:-}" ]; then
		echo "[ERROR]: Bump type is empty! Use '-b=' or '--bump-type=' argument."
		exit 1
	fi

	if [ "${_BUMP_TYPE}" != "major" ] && [ "${_BUMP_TYPE}" != "minor" ] && [ "${_BUMP_TYPE}" != "patch" ]; then
		echo "Bump type '${_BUMP_TYPE}' is invalid, should be: 'major', 'minor' or 'patch'!"
		exit 1
	fi

	if [ "${_IS_COMMIT}" == true ]; then
		if [ -z "$(which git)" ]; then
			echo "[ERROR]: 'git' not found or not installed!"
			exit 1
		fi
	fi


	echo "[INFO]: Checking current version..."
	_current_version="$(./scripts/get-version.sh)"
	echo "[OK]: Current version: '${_current_version}'"

	# Split the version string into its components:
	_major=$(echo "${_current_version}" | cut -d. -f1)
	_minor=$(echo "${_current_version}" | cut -d. -f2)
	_patch=$(echo "${_current_version}" | cut -d. -f3)

	_new_version=${_current_version}
	# Determine the new version based on the type of bump:
	if [ "${_BUMP_TYPE}" == "major" ]; then
		_new_version="$((_major + 1)).0.0"
	elif [ "${_BUMP_TYPE}" == "minor" ]; then
		_new_version="${_major}.$((_minor + 1)).0"
	elif [ "${_BUMP_TYPE}" == "patch" ]; then
		_new_version="${_major}.${_minor}.$((_patch + 1))"
	fi

	echo "[INFO]: Bumping version to '${_new_version}'..."
	# Update the version file with the new version:
	echo -e "__version__ = \"${_new_version}\"" > "${VERSION_FILE_PATH}" || exit 2
	echo "[OK]: New version: '${_new_version}'"

	if [ "${_IS_COMMIT}" == true ]; then
		echo "[INFO]: Committing bump version 'v${_new_version}'..."
		# Commit the updated version file:
		git add "${VERSION_FILE_PATH}" || exit 2
		git commit -m ":bookmark: Bump version to '${_new_version}'." || exit 2
		echo "[OK]: Done."

		if [ "${_IS_TAG}" == true ]; then
			echo "[INFO]: Tagging 'v${_new_version}'..."
			if git rev-parse "v${_new_version}" > /dev/null 2>&1; then
				echo "[ERROR]: 'v${_new_version}' tag is already exists."
				exit 1
			fi
			git tag "v${_new_version}" || exit 2
			echo "[OK]: Done."
		fi

		if [ "${_IS_PUSH}" == true ]; then
			echo "[INFO]: Pushing 'v${_new_version}'..."
			git push || exit 2

			if [ "${_IS_TAG}" == true ]; then
				# shellcheck disable=SC1083
				git push "$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} | sed 's/\/.*//')" "v${_new_version}" || exit 2
			fi
			echo "[OK]: Done."
		fi
	fi
}

main "${@:-}"
## --- Main --- ##
