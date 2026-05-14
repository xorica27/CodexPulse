# CodexPulse 0.3.3

This release fixes a Launch at Login issue.

## What's Fixed

- Turning on Launch at Login no longer starts a second CodexPulse instance immediately.
- Launch at Login still works on the next login.
- Turning Launch at Login off still unloads any existing CodexPulse launch agent.

## Good To Know

If you saw two CodexPulse indicators in the menu bar after enabling Launch at Login, this release is the fix.

This build is ad-hoc signed, so macOS may ask for confirmation the first time you open it. If that happens, right-click `CodexPulse.app`, choose **Open**, then confirm.
