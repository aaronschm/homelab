import express from 'express';
import cors from 'cors';
import { RouterOSAPI } from 'node-routeros';

const app = express();
app.use(cors());
app.use(express.json());

const ROUTER_IP = process.env.ROUTER_IP || '10.10.1.2';
const ROUTER_USER = process.env.ROUTER_USER || 'admin';
const ROUTER_PASS = process.env.ROUTER_PASS || '';

const api = new RouterOSAPI({
    host: ROUTER_IP,
    user: ROUTER_USER,
    password: ROUTER_PASS
});

app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', router: ROUTER_IP });
});

app.get('/api/interfaces', async (req, res) => {
    try {
        await api.connect();
        const interfaces = await api.write('/interface/print');
        api.close();
        res.json(interfaces);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

const port = process.env.PORT || 4000;
app.listen(port, () => {
    console.log(`Backend listening on port ${port}`);
});
