#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

# Initial setup
TARGET_BRANCH="deploy/test"
SOURCE_BRANCH="develop"
BRANCHES=("feature/ATM-113" "feature/ATM-969" "feature/ATM-714" "feature/ATM-876")
MERGED_LOG=".merged_branches.log"

# Ensure branches are up to date
echo -e "${BLUE}Fetching latest updates from origin...${NC}"
git fetch origin

# Create merged log file if it doesn't exist
if [ ! -f "$MERGED_LOG" ]; then
    echo -e "${YELLOW}Creating merged branches log file...${NC}"
    touch $MERGED_LOG
fi

# Recreate deploy/test only if not already on the branch
if ! git rev-parse --verify $TARGET_BRANCH >/dev/null 2>&1; then
    echo -e "${YELLOW}Recreating ${TARGET_BRANCH} from ${SOURCE_BRANCH}...${NC}"
    git branch -D $TARGET_BRANCH 2>/dev/null || echo -e "${RED}Branch ${TARGET_BRANCH} does not exist locally.${NC}"
    git checkout $SOURCE_BRANCH
    git pull origin $SOURCE_BRANCH
    git checkout -b $TARGET_BRANCH
    echo "" > $MERGED_LOG # Reset the merged branches log
else
    echo -e "${GREEN}${TARGET_BRANCH} already exists. Continuing from its current state...${NC}"
fi

# Merge each branch in order
echo -e "${GREEN}Merging branches into ${TARGET_BRANCH}...${NC}"
for BRANCH in "${BRANCHES[@]}"; do
    if grep -q "^$BRANCH$" $MERGED_LOG; then
        echo -e "${YELLOW}Skipping ${BRANCH}, already merged.${NC}"
        continue
    fi
    echo -e "${BLUE}Merging ${BRANCH}...${NC}"
    git fetch origin $BRANCH
    git merge --no-ff origin/$BRANCH -m "Merge branch $BRANCH into $TARGET_BRANCH"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Merge conflict detected in ${BRANCH}. Resolve the conflict, commit, and rerun the script.${NC}"
        exit 1
    fi
    echo $BRANCH >> $MERGED_LOG
done

# Push to remote
echo -e "${YELLOW}Pushing changes to remote...${NC}"
git push origin -f $TARGET_BRANCH

echo -e "${GREEN}All branches have been successfully merged into ${TARGET_BRANCH}.${NC}"
