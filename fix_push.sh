#!/bin/bash

# Script to handle git push conflicts
# Usage: ./fix_push.sh

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Remote has changes. Let's fix this...${NC}"
echo "Choose how to handle the remote changes:"
echo "1) Merge remote changes with local (recommended if remote has important work)"
echo "2) Force push local changes (WARNING: overwrites remote - use only if remote can be discarded)"
echo "3) Rebase local changes on top of remote"
echo "4) Exit and handle manually"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo -e "${GREEN}Merging remote changes...${NC}"
        
        # Set git config if not set
        git config user.email > /dev/null 2>&1 || git config user.email "you@example.com"
        git config user.name > /dev/null 2>&1 || git config user.name "Your Name"
        
        # Pull with merge strategy
        git pull origin main --allow-unrelated-histories || git pull origin master --allow-unrelated-histories
        
        # Check for merge conflicts
        if git diff --name-only --diff-filter=U | grep -q .; then
            echo -e "${YELLOW}Merge conflicts detected in:${NC}"
            git diff --name-only --diff-filter=U
            echo -e "${RED}Please resolve conflicts manually, then run:${NC}"
            echo "git add ."
            echo "git commit"
            echo "git push origin main"
            exit 1
        else
            echo -e "${GREEN}Merge successful! Pushing...${NC}"
            git push origin main || git push origin master
            echo -e "${GREEN}Successfully pushed to remote!${NC}"
        fi
        ;;
        
    2)
        echo -e "${RED}WARNING: This will overwrite the remote repository!${NC}"
        read -p "Are you SURE you want to force push? (type 'yes' to confirm): " confirm
        
        if [ "$confirm" = "yes" ]; then
            echo -e "${YELLOW}Force pushing...${NC}"
            git push --force origin main || git push --force origin master
            echo -e "${GREEN}Force push complete!${NC}"
        else
            echo "Force push cancelled"
            exit 0
        fi
        ;;
        
    3)
        echo -e "${GREEN}Rebasing local changes on remote...${NC}"
        
        # Set git config if not set
        git config user.email > /dev/null 2>&1 || git config user.email "you@example.com"
        git config user.name > /dev/null 2>&1 || git config user.name "Your Name"
        
        # Fetch and rebase
        git fetch origin
        git rebase origin/main || git rebase origin/master
        
        # Check for rebase conflicts
        if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
            echo -e "${YELLOW}Rebase conflicts detected!${NC}"
            echo -e "${RED}Please resolve conflicts, then run:${NC}"
            echo "git rebase --continue"
            echo "git push origin main"
            exit 1
        else
            echo -e "${GREEN}Rebase successful! Pushing...${NC}"
            git push origin main || git push origin master
            echo -e "${GREEN}Successfully pushed to remote!${NC}"
        fi
        ;;
        
    4)
        echo "Exiting. You can handle this manually with:"
        echo "  git pull origin main --allow-unrelated-histories"
        echo "  # resolve any conflicts"
        echo "  git push origin main"
        exit 0
        ;;
        
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Done!${NC}"