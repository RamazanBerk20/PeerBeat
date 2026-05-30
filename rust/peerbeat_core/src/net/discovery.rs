//! mDNS/DNS-SD discovery via `mdns-sd` (advertise + browse), no Avahi dependency.

use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant};

const SERVICE: &str = "_peerbeat._tcp.local.";

/// A discovered host on the LAN.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HostInfo {
    pub name: String,
    pub address: String,
    pub port: u16,
}

/// Advertise this host under `_peerbeat._tcp` with a `name` TXT property.
pub fn register(daemon: &ServiceDaemon, name: &str, port: u16) -> anyhow::Result<()> {
    let ip = local_ip_address::local_ip()
        .map(|i| i.to_string())
        .unwrap_or_default();
    let host_name = format!("peerbeat-{port}.local.");
    let instance = format!("PeerBeat-{port}");
    let mut props = HashMap::new();
    props.insert("name".to_string(), name.to_string());
    let info = ServiceInfo::new(SERVICE, &instance, &host_name, ip.as_str(), port, props)?
        .enable_addr_auto();
    daemon.register(info)?;
    Ok(())
}

/// Browse for peers for up to `timeout`, returning the resolved hosts.
pub fn browse(timeout: Duration) -> Vec<HostInfo> {
    let Ok(daemon) = ServiceDaemon::new() else {
        return vec![];
    };
    let Ok(rx) = daemon.browse(SERVICE) else {
        return vec![];
    };
    let mut hosts: Vec<HostInfo> = Vec::new();
    let deadline = Instant::now() + timeout;
    loop {
        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            break;
        }
        match rx.recv_timeout(remaining) {
            Ok(ServiceEvent::ServiceResolved(info)) => {
                if let Some(addr) = info.get_addresses_v4().into_iter().next() {
                    let name = info
                        .txt_properties
                        .get_property_val_str("name")
                        .map(|s| s.to_string())
                        .unwrap_or_else(|| info.fullname.clone());
                    let address = addr.to_string();
                    if !hosts
                        .iter()
                        .any(|h| h.address == address && h.port == info.get_port())
                    {
                        hosts.push(HostInfo {
                            name,
                            address,
                            port: info.get_port(),
                        });
                    }
                }
            }
            Ok(_) => {}
            Err(_) => break,
        }
    }
    let _ = daemon.shutdown();
    hosts
}
