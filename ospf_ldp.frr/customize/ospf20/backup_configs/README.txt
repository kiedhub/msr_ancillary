# Configuration Backups

Configuration files (frr.conf) may get overwritten, when ip addresses change.
This directory stores copies of the deleted/overwritten configuration files allowing to not lose any changes made to the router after initial container composition.

Timestamp of the deletion is added to the filename.

These backup files are not included/added to the git repository!
