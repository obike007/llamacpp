#!/bin/bash

# Script to move files to llamacpp git repository
# Usage: ./move_to_git.sh

set -e  # Exit on error

# Configuration
REPO_URL="https://github.com/obike007/llamacpp.git"
REPO_NAME="llamacpp"
SOURCE_DIR="$(pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting migration to Git repository...${NC}"

# Check if we're already in a git repo
if [ -d .git ]; then
    echo -e "${YELLOW}Current directory is already a git repository${NC}"
    read -p "Do you want to add the remote and push? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Add remote if it doesn't exist
        if ! git remote get-url origin >/dev/null 2>&1; then
            git remote add origin "$REPO_URL"
            echo -e "${GREEN}Added remote origin${NC}"
        else
            echo -e "${YELLOW}Remote origin already exists${NC}"
            git remote -v
        fi
        
        # Create .gitignore if it doesn't exist
        if [ ! -f .gitignore ]; then
            cat > .gitignore << 'EOF'
# Build artifacts
/build/
*.o
*.a
*.so
*.dylib
*.dll
*.exe

# CMake files
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
compile_commands.json
CTestTestfile.cmake
DartConfiguration.tcl
Testing/
Makefile

# Generated config files
llama-config.cmake
llama-version.cmake
llama.pc

# Python
__pycache__/
*.py[cod]
*$py.class
*.egg-info/
dist/
.pytest_cache/

# Models (usually large files)
*.bin
*.gguf
*.ggml

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
EOF
            echo -e "${GREEN}Created .gitignore file${NC}"
        fi
        
        # Add all files
        git add .
        
        # Show status
        echo -e "${GREEN}Git status:${NC}"
        git status
        
        # Commit
        read -p "Enter commit message (or press Enter for default): " commit_msg
        if [ -z "$commit_msg" ]; then
            commit_msg="Add llamacpp files and build artifacts"
        fi
        git commit -m "$commit_msg"
        
        # Push
        echo -e "${GREEN}Pushing to repository...${NC}"
        git push -u origin main || git push -u origin master
        
        echo -e "${GREEN}Successfully pushed to $REPO_URL${NC}"
    fi
else
    echo -e "${YELLOW}Current directory is not a git repository${NC}"
    echo "Choose an option:"
    echo "1) Initialize git here and push to remote"
    echo "2) Clone the remote repo and copy files there"
    echo "3) Exit"
    
    read -p "Enter choice (1-3): " choice
    
    case $choice in
        1)
            # Initialize and push
            git init
            echo -e "${GREEN}Initialized git repository${NC}"
            
            # Create .gitignore
            cat > .gitignore << 'EOF'
# Build artifacts
/build/
*.o
*.a
*.so
*.dylib
*.dll
*.exe

# CMake files
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
compile_commands.json
CTestTestfile.cmake
DartConfiguration.tcl
Testing/
Makefile

# Generated config files
llama-config.cmake
llama-version.cmake
llama.pc

# Python
__pycache__/
*.py[cod]
*$py.class
*.egg-info/
dist/
.pytest_cache/

# Models (usually large files)
*.bin
*.gguf
*.ggml

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
EOF
            echo -e "${GREEN}Created .gitignore file${NC}"
            
            # Add remote
            git remote add origin "$REPO_URL"
            
            # Create initial branch
            git checkout -b main
            
            # Add files
            git add .
            
            # Commit
            git commit -m "Initial commit: Add llamacpp files"
            
            # Push
            echo -e "${GREEN}Pushing to repository...${NC}"
            git push -u origin main
            
            echo -e "${GREEN}Successfully initialized and pushed to $REPO_URL${NC}"
            ;;
            
        2)
            # Clone and copy
            echo -e "${GREEN}Cloning repository...${NC}"
            
            # Create temp directory for clone
            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR"
            
            # Clone the repo
            git clone "$REPO_URL" "$REPO_NAME"
            cd "$REPO_NAME"
            
            # Copy all files from source
            echo -e "${GREEN}Copying files...${NC}"
            cp -r "$SOURCE_DIR"/* . 2>/dev/null || true
            
            # Create/update .gitignore
            cat > .gitignore << 'EOF'
# Build artifacts
/build/
*.o
*.a
*.so
*.dylib
*.dll
*.exe

# CMake files
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
compile_commands.json
CTestTestfile.cmake
DartConfiguration.tcl
Testing/
Makefile

# Generated config files
llama-config.cmake
llama-version.cmake
llama.pc

# Python
__pycache__/
*.py[cod]
*$py.class
*.egg-info/
dist/
.pytest_cache/

# Models (usually large files)
*.bin
*.gguf
*.ggml

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
EOF
            
            # Add and commit
            git add .
            git commit -m "Add llamacpp files from local build"
            
            # Push
            echo -e "${GREEN}Pushing to repository...${NC}"
            git push
            
            echo -e "${GREEN}Successfully pushed to $REPO_URL${NC}"
            echo -e "${YELLOW}Files are now in: $TEMP_DIR/$REPO_NAME${NC}"
            echo -e "${YELLOW}You may want to move this to a permanent location${NC}"
            ;;
            
        3)
            echo "Exiting..."
            exit 0
            ;;
            
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
fi

echo -e "${GREEN}Done!${NC}"