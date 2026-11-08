/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <glib.h>

static char *stamp;
static char *zone;

void appearance_clock_set(const char *value, const char *timezone)
{
    g_free(stamp);
    g_free(zone);
    stamp = g_strdup(value);
    zone = g_strdup(timezone);
}

GDateTime *__wrap_g_date_time_new_now_local(void)
{
    GDateTime *utc = g_date_time_new_from_iso8601(stamp, NULL);
    GTimeZone *tz = g_time_zone_new_identifier(zone);
    GDateTime *local = g_date_time_to_timezone(utc, tz);

    g_date_time_unref(utc);
    g_time_zone_unref(tz);
    return local;
}
