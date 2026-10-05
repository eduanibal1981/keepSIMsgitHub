package com.keep_sims

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class AlertAlarmTimeTest {
    private fun time(zone: TimeZone, day: Int, hour: Int) = Calendar.getInstance(zone).apply {
        clear(); set(2026, Calendar.OCTOBER, day, hour, 0)
    }.timeInMillis

    @Test fun cutoffAtSixPmKeepsExactly48Hours() {
        val zone = TimeZone.getTimeZone("Asia/Muscat")
        assertEquals(time(zone, 10, 18), AlertAlarmScheduler.alarmTime(time(zone, 12, 18), zone))
    }

    @Test fun morningCutoffUsesEarlierEveningRatherThanLessThan48Hours() {
        val zone = TimeZone.getTimeZone("Asia/Muscat")
        assertEquals(time(zone, 9, 18), AlertAlarmScheduler.alarmTime(time(zone, 12, 10), zone))
    }

    @Test fun lateCutoffUsesSixPmTwoDaysBefore() {
        val zone = TimeZone.getTimeZone("Asia/Muscat")
        assertEquals(time(zone, 10, 18), AlertAlarmScheduler.alarmTime(time(zone, 12, 23), zone))
    }

    @Test fun daylightSavingTransitionStillKeepsLocalSixPmAndMinimumLead() {
        val zone = TimeZone.getTimeZone("America/New_York")
        val cutoff = Calendar.getInstance(zone).apply { clear(); set(2026, Calendar.NOVEMBER, 2, 10, 0) }.timeInMillis
        val alarm = AlertAlarmScheduler.alarmTime(cutoff, zone)
        val civil = Calendar.getInstance(zone).apply { timeInMillis = alarm }
        assertEquals(18, civil.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, civil.get(Calendar.MINUTE))
        assertTrue(cutoff - alarm >= AlertAlarmScheduler.LEAD_MILLIS)
        assertTrue(cutoff - alarm < AlertAlarmScheduler.LEAD_MILLIS + 25 * 60 * 60 * 1000L)
    }

    @Test fun customTimeNineAmSchedulesAtNineAmAtLeast48HoursBefore() {
        val zone = TimeZone.getTimeZone("Asia/Muscat")
        val cutoff = Calendar.getInstance(zone).apply { clear(); set(2026, Calendar.OCTOBER, 12, 12, 0) }.timeInMillis
        val expected = Calendar.getInstance(zone).apply { clear(); set(2026, Calendar.OCTOBER, 10, 9, 0) }.timeInMillis
        assertEquals(expected, AlertAlarmScheduler.alarmTime(cutoff, zone, hour = 9, minute = 0))
    }

    @Test fun customTimeTenPmFallsBackToPreviousDayIfLessThan48Hours() {
        val zone = TimeZone.getTimeZone("Asia/Muscat")
        val cutoff = Calendar.getInstance(zone).apply { clear(); set(2026, Calendar.OCTOBER, 12, 12, 0) }.timeInMillis
        val expected = Calendar.getInstance(zone).apply { clear(); set(2026, Calendar.OCTOBER, 9, 22, 0) }.timeInMillis
        assertEquals(expected, AlertAlarmScheduler.alarmTime(cutoff, zone, hour = 22, minute = 0))
    }
}
