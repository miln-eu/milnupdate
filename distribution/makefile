# makefile to create a distribution ready archive.
# Distributed as part of https://indie.miln.eu

PRODUCT?=milnupdate

# Derive directory paths from makefile location
MAKEFILE_FILE := $(abspath $(lastword $(MAKEFILE_LIST)))
UPDATE_DIR := $(dir $(MAKEFILE_FILE))..

DISTRIBUTION_DIRNAME=distribution
DISTRIBUTION_DIR?=$(UPDATE_DIR)/$(DISTRIBUTION_DIRNAME)

# Extract version from xcconfig file
VERSION?=$(shell grep -o 'MILNUPDATE_VERSION = \d\.\d\.\d\b' $(UPDATE_DIR)/frameworks/version.xcconfig | cut -f3 -d" ")

ARCHIVE_NAME=$(PRODUCT)-$(VERSION)
ARCHIVE_FILEPATH=$(DISTRIBUTION_DIR)/$(ARCHIVE_NAME).tbz

# Build an archive for distribution
release: checkversion
	# Symlink project directory to rename base directory within archive
	ln -sf "$(UPDATE_DIR)" "/tmp/$(ARCHIVE_NAME)"
# tar flags:
#   exclude invisible files; must be first argument
#   L to follow all symlinks
#   c to create a new archive
#   j to compress with bzip
#   f to assign a file name
	cd /tmp/ && tar --exclude=".*" --exclude='$(DISTRIBUTION_DIRNAME)/*.tbz' -Lcjf "/tmp/$(ARCHIVE_NAME).tbz" "$(ARCHIVE_NAME)"
	# Remove the symlink
	rm "/tmp/$(ARCHIVE_NAME)"
	# Copy the archive to the distribution directory
	mkdir -p "$(DISTRIBUTION_DIR)" && cp "/tmp/$(ARCHIVE_NAME).tbz" "$(ARCHIVE_FILEPATH)" && rm "/tmp/$(ARCHIVE_NAME).tbz"
	# Finished

# Ensure extracted version is a three part numeric value
checkversion:
	# Checking version value is valid...
	echo "$(VERSION)" | grep -o '\d\.\d\.\d'; test $$? -eq 0

# Release is not associated with specific files; always perform
.PHONY: release checkversion