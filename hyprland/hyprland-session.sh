#!/usr/bin/sh
#
# Wrapper for starting Hyprland with proper systemd session integration.
#
# Activates hyprland-session.target (which binds to graphical-session.target)
# after Hyprland is ready, enabling systemd-managed services like
# xdg-desktop-portal to auto-start.
#
# If UWSM is managing the session, this script is not used (the
# hyprland-uwsm.desktop entry calls uwsm directly instead).
#
# Based on sway-systemd's session.sh approach.
#

SESSION_TARGET="hyprland-session.target"
SESSION_SHUTDOWN_TARGET="hyprland-session-shutdown.target"

VARIABLES="XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE"
VARIABLES="${VARIABLES} DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE"
VARIABLES="${VARIABLES} XCURSOR_THEME XCURSOR_SIZE"

session_setup() {
    # Wait for Hyprland to be ready (IPC socket available)
    while ! hyprctl version > /dev/null 2>&1; do
        sleep 0.5
    done

    export XDG_CURRENT_DESKTOP=Hyprland
    export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-Hyprland}"
    export XDG_SESSION_TYPE=wayland

    # Propagate environment to D-Bus and systemd
    if hash dbus-update-activation-environment 2>/dev/null; then
        # shellcheck disable=SC2086
        dbus-update-activation-environment --systemd $VARIABLES
    fi
    # shellcheck disable=SC2086
    systemctl --user import-environment $VARIABLES

    # Activate the session target (this pulls in graphical-session.target)
    systemctl --user start "$SESSION_TARGET"
}

session_cleanup() {
    systemctl --user start --job-mode=replace-irreversibly "$SESSION_SHUTDOWN_TARGET"
    if [ -n "$VARIABLES" ]; then
        # shellcheck disable=SC2086
        systemctl --user unset-environment $VARIABLES
    fi
}

# Run session setup in the background so Hyprland can start immediately
session_setup &

# Start Hyprland via the watchdog wrapper
/usr/bin/start-hyprland "$@"
rc=$?

# Hyprland has exited — clean up the session
session_cleanup

exit $rc
