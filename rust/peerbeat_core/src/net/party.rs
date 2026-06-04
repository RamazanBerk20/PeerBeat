//! Party mode: a host drives synchronized playback for connected peers.
//!
//! This module owns the *protocol math* — Cristian clock synchronization and the
//! target-position calculation — independent of the transport. A peer first
//! estimates its offset from the host clock with a few ping/pong samples, then
//! interprets each broadcast [`PartyState`] against that offset to seek to the
//! right spot (target ≤ ~100 ms drift on a LAN). The WebSocket control channel
//! that carries these messages layers on top.

use serde::{Deserialize, Serialize};

/// What the host broadcasts on every change (and periodically): which track is
/// playing, where, and the host clock time the snapshot was taken.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PartyState {
    /// Stable cross-peer track identity (content hash) so peers resolve it in
    /// their own library or stream it from the host.
    pub track_key: String,
    pub position_ms: i64,
    pub playing: bool,
    /// Host monotonic-ish clock (ms) when this snapshot was taken.
    pub host_time_ms: i64,
}

/// One Cristian round-trip sample: peer-send `t0`, host-reply `th`, peer-recv `t1`
/// (all in each party's own clock).
#[derive(Debug, Clone, Copy)]
pub struct SyncSample {
    pub t0: i64,
    pub th: i64,
    pub t1: i64,
}

impl SyncSample {
    pub fn rtt(&self) -> i64 {
        (self.t1 - self.t0).max(0)
    }

    /// Estimated offset to add to the peer clock to get host time, assuming a
    /// symmetric path: `host ≈ peer + offset`.
    pub fn offset(&self) -> i64 {
        self.th - (self.t0 + self.t1) / 2
    }
}

/// Pick the best offset estimate from several samples: the one with the lowest
/// round-trip time (least path asymmetry / queuing error). Returns 0 if empty.
pub fn best_offset(samples: &[SyncSample]) -> i64 {
    samples
        .iter()
        .min_by_key(|s| s.rtt())
        .map(|s| s.offset())
        .unwrap_or(0)
}

/// Where the peer should be *now*, given a broadcast state, the peer's current
/// local clock, and its estimated host-clock offset. While playing, advance the
/// snapshot position by the host-time elapsed since it was taken; when paused,
/// hold. Never returns negative.
pub fn target_position_ms(state: &PartyState, peer_now_ms: i64, offset_ms: i64) -> i64 {
    if !state.playing {
        return state.position_ms.max(0);
    }
    let peer_now_in_host = peer_now_ms + offset_ms;
    let elapsed = peer_now_in_host - state.host_time_ms;
    (state.position_ms + elapsed).max(0)
}

/// Whether the peer should hard-seek to `target` rather than let playback drift
/// in: true when it is off by more than `tolerance_ms` (≈100 ms on a LAN).
pub fn needs_resync(current_ms: i64, target_ms: i64, tolerance_ms: i64) -> bool {
    (current_ms - target_ms).abs() > tolerance_ms
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn offset_and_rtt_from_symmetric_path() {
        // Peer clock is 1000 ms behind the host; one-way latency 20 ms.
        // peer sends at t0=0 (host time 1000); host stamps th at 1000+20=1020;
        // peer receives at t1=40 (40 ms RTT).
        let s = SyncSample { t0: 0, th: 1020, t1: 40 };
        assert_eq!(s.rtt(), 40);
        // offset = 1020 - (0+40)/2 = 1000  → peer + 1000 = host
        assert_eq!(s.offset(), 1000);
    }

    #[test]
    fn best_offset_prefers_lowest_rtt() {
        let samples = [
            SyncSample { t0: 0, th: 1100, t1: 200 }, // rtt 200, noisy
            SyncSample { t0: 0, th: 1020, t1: 40 },  // rtt 40, clean → offset 1000
        ];
        assert_eq!(best_offset(&samples), 1000);
        assert_eq!(best_offset(&[]), 0);
    }

    #[test]
    fn target_advances_while_playing_and_holds_when_paused() {
        // Host took the snapshot at host_time 5000 with position 30000 ms, playing.
        let state = PartyState {
            track_key: "abc".into(),
            position_ms: 30_000,
            playing: true,
            host_time_ms: 5_000,
        };
        // Peer clock at 4200 with offset +1000 → host-now 5200 → 200 ms elapsed.
        assert_eq!(target_position_ms(&state, 4_200, 1_000), 30_200);

        let paused = PartyState { playing: false, ..state.clone() };
        assert_eq!(target_position_ms(&paused, 9_999, 1_000), 30_000);
    }

    #[test]
    fn resync_only_past_tolerance() {
        assert!(!needs_resync(30_000, 30_080, 100)); // 80 ms drift — ride it out
        assert!(needs_resync(30_000, 30_500, 100)); // 500 ms — hard seek
    }
}
