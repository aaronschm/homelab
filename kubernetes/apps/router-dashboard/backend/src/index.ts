import express from 'express';
import cors from 'cors';
import { RouterOSAPI } from 'node-routeros';
import fs from 'fs/promises';
import path from 'path';
import nacl from 'tweetnacl';

const app = express();
app.use(cors());
app.use(express.json());

const ROUTER_IP = process.env.ROUTER_IP || '10.10.1.2';
const ROUTER_USER = process.env.ROUTER_USER || 'admin';
const ROUTER_PASS = process.env.ROUTER_PASS || '';
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '..', 'data');
const CLIENTS_FILE = path.join(DATA_DIR, 'clients.json');
const ENDPOINT_HOST = process.env.WG_ENDPOINT || 'isarcloud.eu';

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

fs.mkdir(DATA_DIR, { recursive: true }).catch(() => {});

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

app.post('/api/wireguard/peer', async (req, res) => {
    const { interfaceName, comment, allowedAddress } = req.body;
    try {
        // Fetch interface info to get server pubkey and port
        const ifaces = await runApiCommand('/interface/wireguard/print');
        const serverIface = ifaces.find((i: any) => i.name === interfaceName);
        if (!serverIface) throw new Error("Interface not found");

        const serverPubKey = serverIface['public-key'];
        const serverPort = serverIface['listen-port'];

        // Generate client keypair
        const keyPair = nacl.box.keyPair();
        const privKeyBase64 = Buffer.from(keyPair.secretKey).toString('base64');
        const pubKeyBase64 = Buffer.from(keyPair.publicKey).toString('base64');

        // Add to Router
        await runApiCommand('/interface/wireguard/peers/add', [
            `=interface=${interfaceName}`,
            `=public-key=${pubKeyBase64}`,
            `=allowed-address=${allowedAddress}`,
            `=comment=${comment}`
        ]);

        // Construct Config
        const clientIp = allowedAddress.split('/')[0]; // Extract IP without subnet for address if needed, but WG config usually takes the /32
        const configStr = `[Interface]
PrivateKey = ${privKeyBase64}
Address = ${allowedAddress}

[Peer]
PublicKey = ${serverPubKey}
Endpoint = ${ENDPOINT_HOST}:${serverPort}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
`;

        res.json({ success: true, config: configStr, publicKey: pubKeyBase64 });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// --- FIREWALL NAT ---
app.get('/api/firewall/nat', async (req, res) => {
    try {
        const rules = await runApiCommand('/ip/firewall/nat/print');
        res.json(rules);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/firewall/nat', async (req, res) => {
    const { comment, protocol, dstPort, toAddress, toPort, inInterface } = req.body;
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
        
        await runApiCommand('/ip/firewall/nat/add', args);
        res.json({ success: true });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// --- BRIDGE VLANS ---
app.get('/api/bridge', async (req, res) => {
    try {
        const vlans = await runApiCommand('/interface/bridge/vlan/print');
        const ports = await runApiCommand('/interface/bridge/port/print');
        res.json({ vlans, ports });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/bridge/port/pvid', async (req, res) => {
    const { id, pvid } = req.body;
    try {
        await runApiCommand('/interface/bridge/port/set', [`=.id=${id}`, `=pvid=${pvid}`]);
        res.json({ success: true });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// ... [rest of index.ts for clients, firewall filter, interfaces] ...
app.get('/api/interfaces', async (req, res) => {
    try { res.json(await runApiCommand('/interface/print')); } 
    catch (e: any) { res.status(500).json({ error: e.message }); }
});

app.get('/api/clients', async (req, res) => {
    try {
        let customNames: Record<string, string> = {};
        try { customNames = JSON.parse(await fs.readFile(CLIENTS_FILE, 'utf-8')); } catch (err) {}
        const dhcpLeases = await runApiCommand('/ip/dhcp-server/lease/print');
        const arpEntries = await runApiCommand('/ip/arp/print');
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
    try { res.json(await runApiCommand('/ip/firewall/filter/print')); }
    catch (e: any) { res.status(500).json({ error: e.message }); }
});

const port = process.env.PORT || 4000;
app.listen(port, () => console.log(`Backend listening on port ${port}`));
