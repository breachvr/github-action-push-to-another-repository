#!/bin/sh -l

# Tests:
# If no repo, fail and tell user what is wrong
# If repo but no branch and not create, fail and tell user what is wrong
# adding file
# changing file
# removing file


set -e  # if a command fails it stops the execution
set -u  # script fails if trying to access to an undefined variable

echo "[+] Action start"
SOURCE_BEFORE_DIRECTORY="${1}"
SOURCE_DIRECTORY="${2}"
DESTINATION_GITHUB_USERNAME="${3}"
DESTINATION_REPOSITORY_NAME="${4}"
GITHUB_SERVER="${5}"
USER_EMAIL="${6}"
USER_NAME="${7}"
DESTINATION_REPOSITORY_USERNAME="${8}"
TARGET_BRANCH="${9}"
CREATE_BRANCH="${10}"
COMMIT_MESSAGE="${11}"
TARGET_DIRECTORY="${12}"

if [ -z "$DESTINATION_REPOSITORY_USERNAME" ]
then
	DESTINATION_REPOSITORY_USERNAME="$DESTINATION_GITHUB_USERNAME"
fi

if [ -z "$USER_NAME" ]
then
	USER_NAME="$DESTINATION_GITHUB_USERNAME"
fi

CLONE_DIR=$(mktemp -d)

echo "[+] Git version"
git --version
git-lfs --version

echo "[+] Setup git $DESTINATION_REPOSITORY_NAME"
# Setup git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

echo "[+] Checking out LFS objects"
git lfs checkout

echo "[+] Set directory is safe ($CLONE_DIR)"
# Related to https://github.com/cpina/github-action-push-to-another-repository/issues/64 and https://github.com/cpina/github-action-push-to-another-repository/issues/64
# TODO: review before releasing it as a version
git config --global --add safe.directory "$CLONE_DIR"
# git config --global --add safe.directory /github/workspace


# git status

echo "[+] Checking if remote exists"
if [[ -z "$(git ls-remote "https://$USER_NAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git")" ]]; then
	echo "::error::Could not find the remote"
	echo "::error::Please verify that the target repository exist AND that it contains a valid main branch AND is accesible by the API_TOKEN_GITHUB"
	exit 1
else
	echo "[+] remote exists, proceeding"
fi


# Check if target branch exists
if [ "$(git ls-remote --heads "https://$USER_NAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git" $TARGET_BRANCH | wc -l)" == "1" ]; then
	echo "[+] Target branch exists, cloning repo"
	git clone --single-branch --branch "$TARGET_BRANCH" "https://$USER_NAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git" "$CLONE_DIR"
else
	echo "[-] Target branch does not exist"

	if [ "$CREATE_BRANCH" ]; then
		echo "[+] Checking out repo then creating branch"
		git config --global --add safe.directory /github/workspace
		git clone --single-branch "https://$USER_NAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git" "$CLONE_DIR"
		# git lfs pull
		# git checkout -b "$TARGET_BRANCH"
		# git status
	else
		echo "[-] Create new branch disabled, exiting"
		exit 1
	fi
fi



# echo "[+] We are cloned and ready to go!"
# git status
# git remote -v

# cd "$CLONE_DIR"
# git status
# git remote -v

# ls -la "$CLONE_DIR"

TEMP_DIR=$(mktemp -d)
# This mv has been the easier way to be able to remove files that were there
# but not anymore. Otherwise we had to remove the files from "$CLONE_DIR",
# including "." and with the exception of ".git/"
mv "$CLONE_DIR/.git" "$TEMP_DIR/.git"

# $TARGET_DIRECTORY is '' by default
ABSOLUTE_TARGET_DIRECTORY="$CLONE_DIR/$TARGET_DIRECTORY/"

echo "[+] Deleting $ABSOLUTE_TARGET_DIRECTORY"
rm -rf "$ABSOLUTE_TARGET_DIRECTORY"

echo "[+] Creating (now empty) $ABSOLUTE_TARGET_DIRECTORY"
mkdir -p "$ABSOLUTE_TARGET_DIRECTORY"

echo "[+] Listing Current Directory Location"
ls -al

echo "[+] Listing root Location"
ls -al /

mv "$TEMP_DIR/.git" "$CLONE_DIR/.git"

echo "[+] List contents of $SOURCE_DIRECTORY"
ls "$SOURCE_DIRECTORY"

echo "[+] Checking if local $SOURCE_DIRECTORY exist"
if [ ! -d "$SOURCE_DIRECTORY" ]
then
	echo "ERROR: $SOURCE_DIRECTORY does not exist"
	echo "This directory needs to exist when push-to-another-repository is executed"
	echo
	echo "In the example it is created by ./build.sh: https://github.com/cpina/push-to-another-repository-example/blob/main/.github/workflows/ci.yml#L19"
	echo
	echo "If you want to copy a directory that exist in the source repository"
	echo "to the target repository: you need to clone the source repository"
	echo "in a previous step in the same build section. For example using"
	echo "actions/checkout@v3. See: https://github.com/cpina/push-to-another-repository-example/blob/main/.github/workflows/ci.yml#L16"
	exit 1
fi

echo "[+] Copying contents of source repository folder $SOURCE_DIRECTORY to folder $TARGET_DIRECTORY in git repo $DESTINATION_REPOSITORY_NAME"
cp -ra "$SOURCE_DIRECTORY"/. "$CLONE_DIR/$TARGET_DIRECTORY"
cd "$CLONE_DIR"

# TODO: Don't think that is neccesary
echo "[+] Pull Git LFS objects"
git lfs pull

# cd "$CLONE_DIR"
# cd ..

echo "[+] Files that will be pushed"
ls -la

# TODO: We are either already
git checkout -b "$TARGET_BRANCH"

ORIGIN_COMMIT="https://$GITHUB_SERVER/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
COMMIT_MESSAGE="${COMMIT_MESSAGE/ORIGIN_COMMIT/$ORIGIN_COMMIT}"
COMMIT_MESSAGE="${COMMIT_MESSAGE/\$GITHUB_REF/$GITHUB_REF}"

echo "[+] Adding git commit"
git add .

echo "[+] git status:"
git status

# echo "[+] showing git refs:"
# git show-ref

# # echo "[+] git diff-index:"
# # # git diff-index : to avoid doing the git commit failing if there are no changes to be commit
# # git diff-index --quiet HEAD || 
echo "[+] comitting changes"
git commit --message "$COMMIT_MESSAGE"

echo "[+] listing remotes"
git remote -v

echo "[+] Pushing git commit"
# # # --set-upstream: sets the branch when pushing to a branch that does not exist
# git push "https://$USER_NAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git" --set-upstream "$TARGET_BRANCH"
git push origin "$TARGET_BRANCH" --set-upstream

echo "[+] Pushing LFS files"
git lfs push origin "$TARGET_BRANCH"
