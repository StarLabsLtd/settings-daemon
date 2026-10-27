/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <gio/gio.h>

/* Keep the provider's network policy deterministic without changing the host. */
gboolean __wrap_g_network_monitor_get_network_metered(GNetworkMonitor *monitor)
{
    return g_strcmp0(g_getenv("TEST_METERED"), "1") == 0;
}
