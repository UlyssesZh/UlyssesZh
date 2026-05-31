#!/usr/bin/env bash

set -euo pipefail

gh auth status
forks=$(gh repo list --fork --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner')

if [ -z "$forks" ]; then
	echo "No forked repositories found."
	exit 0
fi

echo "$forks" | while read -r repo; do
	echo "Processing fork: $repo"
	upstream_info=$(gh api graphql -f query='
		query($name: String!, $owner: String!) {
			repository(name: $name, owner: $owner) {
				parent {
					defaultBranchRef {
						name
					}
				}
			}
		}' -F owner="${repo%/*}" -F name="${repo#*/}" --jq '.data.repository.parent.defaultBranchRef.name')

	if [ -z "$upstream_info" ] || [ "$upstream_info" = "null" ]; then
		echo "::error::Could not find upstream repository info for $repo."
		continue
	fi

	echo "Upstream default branch identified as: $upstream_info"
	if ! gh repo sync "$repo" --branch "$upstream_info"; then
		echo "::error::Failed to sync $repo"
	fi
done
