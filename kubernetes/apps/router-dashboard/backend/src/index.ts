import express from 'express';
import cors from 'cors';
import { RouterOSAPI } from 'node-routeros';
import fs from 'fs/promises';
import path from 'path';

const app = express();
// Restrict CORS to the dashboard's own origin only.
// The nginx sidecar already proxies /api, so external browsers never hit this
// port directly — this is a defence-in-depth measure.
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || 'https://network.isarcloud.eu';
app.use(cors({ origin: ALLOWED_ORIGIN, credentials: true }));
app.use(express.json());

// Primary router (CRS309 — main gateway/WireGuard/NAT host)
const ROUTER_IP   = process.env.ROUTER_IP   || '10.10.1.2';
const ROUTER_USER = process.env.ROUTER_USER || 'network-dashboard';
const ROUTER_PASS = process.env.ROUTER_PASS || '';

// Secondary router (CRS310 — switch)
const ROUTER_IP_2   = process.env.ROUTER_IP_2   || '';
const ROUTER_USER_2 = process.env.ROUTER_USER_2 || ROUTER_USER;
const ROUTER_PASS_2 = process.env.ROUTER_PASS_2 || ROUTER_PASS;

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '..', 'data');
const CLIENTS_FILE = path.join(DATA_DIR, 'clients.json');
const ENDPOINT_HOST = process.env.WG_ENDPOINT || 'isarcloud.eu';

// List of configured routers — returned by /api/routers so the UI knows
// which devices are available. If ROUTER_IP_2 is empty, only one router exists.
const ROUTERS = [
  { id: 'primary', label: 'CRS309 (Gateway)', ip: ROUTER_IP },
  ...(ROUTER_IP_2 ? [{ id: 'secondary', label: 'CRS310 (Switch)', ip: ROUTER_IP_2 }] : []),
];

function getApi(target = 'primary') {
  const ip   = target === 'secondary' && ROUTER_IP_2 ? ROUTER_IP_2 : ROUTER_IP;
  const user = target === 'secondary' && ROUTER_USER_2 ? ROUTER_USER_2 : ROUTER_USER;
  const pass = target === 'secondary' && ROUTER_PASS_2 ? ROUTER_PASS_2 : ROUTER_PASS;
  return new RouterOSAPI({ host: ip, user, password: pass, keepalive: true });
}

async function runApiCommand(command: string, args: string[] = [], target = 'primary') {
    const api = getApi(target);
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

fs.mkdir(DATA_DIR, { recursive: true }).catch(() => {});

// List available routers — used by the frontend router selector.
app.get('/api/routers', (_req, res) => {
    res.json(ROUTERS);
});

// --- WIREGUARD ---
app.get('/api/wireguard', async (req, res) => {
    const target = (req.query.target as string) || 'primary';
    try {
        const interfaces = await runApiCommand('/interface/wireguard/print', [], target);
        const peers = await runApiCommand('/interface/wireguard/peers/print', [], target);
        res.json({ interfaces, peers });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/wireguard/toggle', async (req, res) => {
    const { id, disabled, target = 'primary' } = req.body;
    try {
        await runApiCommand('/interface/wireguard/set', [`=.id=${id}`, `=disabled=${disabled ? 'yes' : 'no'}`], target);
        res.json({ success: true });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/wireguard/peer', async (req, res) => {
    const { interfaceName, comment, allowedAddress, endpointHost, clientPublicKey, target = 'primary' } = req.body;
    if (!clientPublicKey) {
        return res.status(400).json({ error: 'clientPublicKey is required — generate it in the browser' });
    }
    const host = endpointHost || process.env.WG_ENDPOINT || 'isarcloud.eu';
    try {
        const ifaces = await runApiCommand('/interface/wireguard/print', [], target);
        const serverIface: any = ifaces.find((i: any) => i.name === interfaceName);
        if (!serverIface) throw new Error("Interface not found");

        const serverPublicKey = serverIface['public-key'];
        const serverPort = serverIface['listen-port'];

        // Register the client's public key on the router.
        // The private key was generated in the browser and is NEVER sent here.
        await runApiCommand('/interface/wireguard/peers/add', [
            `=interface=${interfaceName}`,
            `=public-key=${clientPublicKey}`,
            `=allowed-address=${allowedAddress}`,
            `=comment=${comment}`
        ], target);

        // Return only server-side info; the browser builds the full config.
        res.json({
            success: true,
            serverPublicKey,
            endpoint: `${host}:${serverPort}`,
        });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// --- FIREWALL NAT ---
app.get('/api/firewall/nat', async (req, res) => {
    const target = (req.query.target as string) || 'primary';
    try {
        const rules = await runApiCommand('/ip/firewall/nat/print', [], target);
        res.json(rules);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/firewall/nat', async (req, res) => {
    const { comment, protocol, dstPort, toAddress, toPort, inInterface, target = 'primary' } = req.body;
    try {
        const args = [
            `=chain=dstnat`,
            `=action=dst-nat`,
            `=protocol=${protocol}`,
            `=dst-port=${dstPort}`,
            `=to-addresses=${toAddress}`,
            `=to-ports=${toPort}`,
            `=comment=${comment}`
        ];
        if (inInterface) args.push(`=in-interface=${inInterface}`);
        
        await runApiCommand('/ip/firewall/nat/add', args, target);
        res.json({ success: true });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// --- BRIDGE VLANS ---
app.get('/api/bridge', async (req, res) => {
    const target = (req.query.target as string) || 'primary';
    try {
        const vlans = await runApiCommand('/interface/bridge/vlan/print', [], target);
        const ports = await runApiCommand('/interface/bridge/port/print', [], target);
        res.json({ vlans, ports });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/bridge/port/pvid', async (req, res) => {
    const { id, pvid, target = 'primary' } = req.body;
    try {
        await runApiCommand('/interface/bridge/port/set', [`=.id=${id}`, `=pvid=${pvid}`], target);
        res.json({ success: true });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// ... [rest of index.ts for clients, firewall filter, interfaces] ...
app.get('/api/interfaces', async (req, res) => {
    const target = (req.query.target as string) || 'primary';
    try { res.json(await runApiCommand('/interface/print', [], target)); } 
    catch (e: any) { res.status(500).json({ error: e.message }); }
});

app.get('/api/clients', async (req, res) => {
    const target = (req.query.target as string) || 'primary';
    try {
        let customNames: Record<string, string> = {};
        try { customNames = JSON.parse(await fs.readFile(CLIENTS_FILE, 'utf-8')); } catch (err) {}
        const dhcpLeases = await runApiCommand('/ip/dhcp-server/lease/print', [], target);
        const arpEntries = await runApiCommand('/ip/arp/print', [], target);
        const clients = new Map();
        arpEntries.forEach((entry: any) => {
            if (entry['mac-address']) {
                clients.set(entry['mac-address'], {
                    mac: entry['mac-address'], ip: entry['address'], interface: entry['interface'],
                    customName: customNames[entry['mac-address']] || null, type: 'arp'
                });
            }
        });
        dhcpLeases.forEach((lease: any) => {
            if (lease['mac-address']) {
                const existing = clients.get(lease['mac-address']) || {};
                clients.set(lease['mac-address'], {
                    ...existing, mac: lease['mac-address'], ip: lease['address'], hostname: lease['host-name'] || '',
                    status: lease['status'], customName: customNames[lease['mac-address']] || null, type: 'dhcp'
                });
            }
        });
        res.json(Array.from(clients.values()));
    } catch (e: any) { res.status(500).json({ error: e.message }); }
});

app.post('/api/clients/name', async (req, res) => {
    const { mac, name } = req.body;
    try {
        let customNames: Record<string, string> = {};
        try { customNames = JSON.parse(await fs.readFile(CLIENTS_FILE, 'utf-8')); } catch (err) {}
        customNames[mac] = name;
        await fs.writeFile(CLIENTS_FILE, JSON.stringify(customNames, null, 2));
        res.json({ success: true, customNames });
    } catch (e: any) { res.status(500).json({ error: e.message }); }
});

app.get('/api/firewall', async (req, res) => {
    const target = (req.query.target as string) || 'primary';
    try { res.json(await runApiCommand('/ip/firewall/filter/print', [], target)); }
    catch (e: any) { res.status(500).json({ error: e.message }); }
});

const port = process.env.PORT || 4000;
app.listen(port, () => console.log(`Backend listening on port ${port}`));
