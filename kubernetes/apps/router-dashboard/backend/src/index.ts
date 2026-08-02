import express from 'express';
import cors from 'cors';
import { RouterOSAPI } from 'node-routeros';
import fs from 'fs/promises';
import path from 'path';

const app = express();
app.use(cors());
app.use(express.json());

const ROUTER_IP = process.env.ROUTER_IP || '10.10.1.2';
const ROUTER_USER = process.env.ROUTER_USER || 'admin';
const ROUTER_PASS = process.env.ROUTER_PASS || '';
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '..', 'data');
const CLIENTS_FILE = path.join(DATA_DIR, 'clients.json');

const getApi = () => new RouterOSAPI({
    host: ROUTER_IP,
    user: ROUTER_USER,
    password: ROUTER_PASS,
    keepalive: true
});

async function runApiCommand(command: string, args: string[] = []) {
    const api = getApi();
    try {
        await api.connect();
        const res = await api.write(command, args);
        api.close();
        return res;
    } catch (e) {
        api.close();
        throw e;
    }
}

// Ensure data dir exists
fs.mkdir(DATA_DIR, { recursive: true }).catch(() => {});

// --- SYSTEM ---
app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

// --- WIREGUARD ---
app.get('/api/wireguard', async (req, res) => {
    try {
        const interfaces = await runApiCommand('/interface/wireguard/print');
        const peers = await runApiCommand('/interface/wireguard/peers/print');
        res.json({ interfaces, peers });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/wireguard/toggle', async (req, res) => {
    const { id, disabled } = req.body;
    try {
        await runApiCommand('/interface/wireguard/set', [`=.id=${id}`, `=disabled=${disabled ? 'yes' : 'no'}`]);
        res.json({ success: true });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// --- INTERFACES ---
app.get('/api/interfaces', async (req, res) => {
    try {
        const interfaces = await runApiCommand('/interface/print');
        res.json(interfaces);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// --- CLIENTS & MAC TRACKING ---
app.get('/api/clients', async (req, res) => {
    try {
        // Read custom names mapping
        let customNames: Record<string, string> = {};
        try {
            const data = await fs.readFile(CLIENTS_FILE, 'utf-8');
            customNames = JSON.parse(data);
        } catch (err) {}

        const dhcpLeases = await runApiCommand('/ip/dhcp-server/lease/print');
        const arpEntries = await runApiCommand('/ip/arp/print');

        const clients = new Map();
        
        // Merge ARP
        arpEntries.forEach((entry: any) => {
            if (entry['mac-address']) {
                clients.set(entry['mac-address'], {
                    mac: entry['mac-address'],
                    ip: entry['address'],
                    interface: entry['interface'],
                    customName: customNames[entry['mac-address']] || null,
                    type: 'arp'
                });
            }
        });

        // Merge DHCP (can overwrite/augment ARP data)
        dhcpLeases.forEach((lease: any) => {
            if (lease['mac-address']) {
                const existing = clients.get(lease['mac-address']) || {};
                clients.set(lease['mac-address'], {
                    ...existing,
                    mac: lease['mac-address'],
                    ip: lease['address'],
                    hostname: lease['host-name'] || '',
                    status: lease['status'],
                    customName: customNames[lease['mac-address']] || null,
                    type: 'dhcp'
                });
            }
        });

        res.json(Array.from(clients.values()));
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/clients/name', async (req, res) => {
    const { mac, name } = req.body;
    try {
        let customNames: Record<string, string> = {};
        try {
            const data = await fs.readFile(CLIENTS_FILE, 'utf-8');
            customNames = JSON.parse(data);
        } catch (err) {}
        
        customNames[mac] = name;
        await fs.writeFile(CLIENTS_FILE, JSON.stringify(customNames, null, 2));
        
        res.json({ success: true, customNames });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// --- FIREWALL ---
app.get('/api/firewall', async (req, res) => {
    try {
        const rules = await runApiCommand('/ip/firewall/filter/print');
        res.json(rules);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

const port = process.env.PORT || 4000;
app.listen(port, () => {
    console.log(`Backend listening on port ${port}`);
});
